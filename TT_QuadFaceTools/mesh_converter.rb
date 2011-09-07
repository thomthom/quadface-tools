#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # (!) Refactor this into a class that search for connected quads. That way
  #     reusable methods can be made without having to pass a long list of
  #     arguments in order to make the methods aware of the current processing.
  
  # @return [<Array<QuadFace>]
  # @since 0.1.0
  def self.convert_connected_mesh_to_quads
    model = Sketchup.active_model
    selection = model.selection
    faces = selection.select { |e| e.is_a?( Sketchup::Face ) }
    # Allow a dividing edge to be selcted.
    if faces.empty?
      if selection[0].is_a?( Sketchup::Edge )
        edge = selection[0]
        if edge.faces.size == 2 &&
           edge.faces.all? { |f| f.vertices.size == 3 }
          faces = edge.faces
        end
      end
    end
    # Verify selection
    unless (1..2).include?( faces.size )
      UI.messagebox( 'Selection must contain one or two faces represeting a QuadFace or an edge separating two triangles.' )
      return
    end
    time_start = Time.now
    TT::Model.start_operation( 'Convert to QuadFaces' )
    #model.start_operation( 'Convert to QuadFaces' )
    # Validate geometry
    if faces.size == 1
      # Native QuadFace
      face = faces[0]
      unless face.vertices.size == 4
        UI.messagebox( 'Selected face does to represent a QuadFace. Too many vertices.' )
        return 1
      end
      # Convert geometry to QuadFace
      quadface = self.convert_to_quad( face )
    else
      # Triangulated QuadFace
      unless faces.all? { |face| face.vertices.size == 3 }
        UI.messagebox( 'Selected faces does to represent a QuadFace. Too many vertices.' )
        return 2
      end
      face1, face2 = faces
      shared_edges = face1.edges & face2.edges
      if shared_edges.empty?
        UI.messagebox( 'Selected faces does to represent a QuadFace. No shared edge.' )
        return 3
      end
      # Convert geometry to QuadFace
      quadface = self.convert_to_quad( face1, face2, shared_edges[0] )
    end
    
    tagged = []
    stack = [ quadface ]
    # <debug>
    i=0
    j=0
    # </debug>
    until stack.empty?
      # <debug>
      i+=1
      if i > 50000
        puts "LOOP!"
        UI.beep
        break
      end
      # </debug>
      
      
      quad = stack.shift
      next if ( tagged & quad.faces ).size > 0
      
      j+=1 # <debug/>
      
      Sketchup.status_text = "Working... (#{j} QuadFaces found.)"
      TT::SketchUp.refresh
      
      tagged.concat( quad.faces )
      #quad.material = 'pink' # <debug/>
      stack.concat( self.find_connected_quadfaces( quad ) )
      
      # <debug>
      #result = UI.messagebox( "Quad #{j} (#{i})", MB_OKCANCEL )
      #break if result == 2
      # </debug>
      
      #quad.material = 'yellow' # <debug/>
    end
    puts "Iterations: #{j} (#{i})"
    model.commit_operation
    elapsed_time = sprintf( '%.3f', Time.now - time_start )
    puts "#{j} QuadFaces found in #{elapsed_time}s"
    # 264 QuadFaces found in 0.863s ( start_operation - false )
    # 264 QuadFaces found in 0.570s ( start_operation - true )
    # 264 QuadFaces found in 0.491s ( no material= )
  #rescue
    #model.abort_operation
    #raise
  end
  
  # @param [QuadFace] quadface_origin
  #
  # @return [Array<QuadFace>]
  # @since 0.1.0
  def self.find_connected_quadfaces( quadface_origin )
    faces = [] # Unconfirmed
    quadfaces = [] # Confirmed
    tagged = quadface_origin.faces # Faces processed.
    
    # Find confirmed quadfaces connected each vertex. (Native or QuadFace)
    for vertex in quadface_origin.vertices
      for face in vertex.faces
        next if quadface_origin.faces.include?( face )
        next if tagged.include?( face )
        if QuadFace.is?( face )
          quadface = QuadFace.new( face )
          tagged.concat( quadface.faces )
          #quadface.material = [192,255,192] # <debug/>
          quadfaces << quadface
        elsif face.vertices.size == 4
          quadface = self.convert_to_quad( face )
          tagged.concat( quadface.faces )
          #quadface.material = [0,192,0] # <debug/>
          quadfaces << quadface
        elsif face.vertices.size == 3
          faces << face
        end # if QuadFace.is?( face )
      end # for face
    end # for vertex

    # Find faces neigbouring the origin face.
    neighbours = quadface_origin.vertices.map { |v| v.faces }.flatten - quadface_origin.faces
    
    # If any confirmed Quadfaces, start traversing around the origin looking
    # for more.
    i=0 # <debug/>
    stack = quadfaces.dup
    
    # In case there is no confirmed quads around the origin, look for best 
    # possible solution.
    if stack.empty?

      # Find a candiate triangle to start from.
      triangle = nil
      for edge in quadface_origin.edges
        for face in edge.faces
          next unless face.vertices.size == 3
          next if tagged.include?( face )
          triangle = face
          break
        end
        break if triangle
      end
      return [] unless triangle
      
      #triangle.material = 'cyan'
      
      # Find a solution.
      edges = triangle.edges - quadface_origin.edges
      face1, face2 = edges.map { |e| ( e.faces - [triangle] )[0] }
      
      #face1.material = 'orange'
      #face2.material = 'orange'
      #return []
      
      solution = self.find_optimal_quad_solution(
        quadface_origin, quadfaces, tagged, neighbours, triangle, face1, face2 )
        
      #TT.debug "Guess Solutions: #{solution.size}"
      
      for virtual_face in solution
        # All virtual quads are triangulated - if they where native
        # quads, with four vertices, there would be no need for this.
        f1, f2 = virtual_face.faces
        divider = ( f1.edges & f2.edges )[0]
        new_quadface = self.convert_to_quad( f1, f2, divider )
        tagged.concat( new_quadface.faces )
        # <debug>
        #new_quadface.material = [128+(10*i),0,32+(20*i)]
        i+=1
        # </debug>
        quadfaces << new_quadface
        stack << new_quadface
      end
    
    end # stack.empty?
    
    
    # Traverse around the origin from the known quads.
    until stack.empty?
      quadface = stack.shift
      #TT.debug quadface
      # Find neighbour faces to current quadface and origin.
      for edge in quadface.edges
        for face in edge.faces
          next unless face.vertices.size == 3
          next unless neighbours.include?( face )
          next if tagged.include?( face )
          #face.material = 'gray'
          unless ( quadface_origin.edges & face.edges ).size == 1
            #face.material = 'orange'
            # Shares only a vertex with origin.
            # 'face' has two possible matchces - attempting to find the best
            # fit solution.
            
            # Find possible candidates for the opposite triangle.
            # The faces found here are just two faces connected to the
            # triangle we're trying to find a match for.
            # find_optimal_quad_solution() checks the faces to see if they
            # fit the criterias (triangle, not used etc.).
            edges = face.edges - quadface.edges
            face1, face2 = edges.map { |e| ( e.faces - [face] )[0] }
            
            #face1.material = 'red' # <debug/>
            #face2.material = 'red' # <debug/>
            
            # Recursive method that looks for the solution which yields the
            # most quadfaces and leaves the least number of neighbouring faces.
            #TT.debug '----------'
            solution = self.find_optimal_quad_solution(
                quadface_origin, quadfaces, tagged, neighbours, face, face1, face2 )
            #TT.debug "Best Solution: #{solution.size}"
            
            # The solution is an array of VirtualQuadFaces. These must be
            # converted into real QuadFaces and their data added to the
            # current working set.
            for virtual_face in solution
              # All virtual quads are triangulated - if they where native
              # quads, with four vertices, there would be no need for this.
              f1, f2 = virtual_face.faces
              divider = ( f1.edges & f2.edges )[0]
              new_quadface = self.convert_to_quad( f1, f2, divider )
              tagged.concat( new_quadface.faces )
              # <debug>
              #new_quadface.material = [128+(10*i),32+(20*i),0]
              i+=1
              # </debug>
              quadfaces << new_quadface
              stack << new_quadface
            end
            next
          end
          # Shared edge with origin - quadface is a corner.
          divider = ( face.edges - quadface.edges - quadface_origin.edges )[0]
          other_triangle = ( divider.faces - [ face ] )[0]
          next unless other_triangle
          next unless other_triangle.vertices.size == 3
          next if QuadFace.is?( other_triangle )
          next if tagged.include?( other_triangle )
          new_quadface = self.convert_to_quad( face, other_triangle, divider )
          tagged.concat( new_quadface.faces )
          # <debug>
          #new_quadface.material = [0,128+(10*i),32+(20*i)]
          i+=1
          # </debug>
          quadfaces << new_quadface
          stack << new_quadface
        end # edge.faces
      end # quadfaces.edges
    end # until stack.empty?
    quadfaces
  end
  
  
  # @param [QuadFace] origin
  # @param [Array<QuadFace>] existing
  # @param [Array<Sketchup::Face>] tagged
  # @param [Array<Sketchup::Face>] neighbours
  # @param [Sketchup::Face] source Triangle
  # @param [Sketchup::Face] face1
  # @param [Sketchup::Face] face2
  #
  # @return [<Array<VirtualQuadFace>]
  # @since 0.1.0
  def self.find_optimal_quad_solution( origin, existing, tagged, neighbours, source, face1, face2, nn=0 )
    # (!) Argument `nn` is just a debug flag.
    
    # Validate the properties of the possible faces.
    face1_valid = (
      face1 &&
      face1.vertices.size == 3 &&
      !tagged.include?( face1 ) &&
      !QuadFace.is?( face1 )
    )
    face2_valid = (
      face2 &&
      face2.vertices.size == 3 &&
      !tagged.include?( face2 ) &&
      !QuadFace.is?( face2 )
    )
    
=begin
    sel = Sketchup.active_model.selection
    cache = sel.to_a
    sel.clear
    sel.add( face1 ) if face1_valid
    sel.add( face2 ) if face2_valid
    sel.add( source.edges )
    result = UI.messagebox( "Step? (#{nn})", MB_OKCANCEL )
    sel.clear
    sel.add( cache )
    return [] if result == 2
=end
    
    #tab = '  ' * nn
    #TT.debug "#{tab}find_optimal_quad_solution(#{nn})"
    
    # Find possible soution for each face. This is recursive methods.
    s1 = s2 = []
    if face1_valid
      #face1.material = 'red'
      s1 = self.find_possible_quads( origin, existing, tagged, neighbours, source, face1, nn )
      #face1.material = [64,64,64] if s1.empty?
    end
    if face2_valid
      #face2.material = 'red'
      s2 = self.find_possible_quads( origin, existing, tagged, neighbours, source, face2, nn )
      #face2.material = [64,64,64] if s2.empty?
    end
    
    #tab = '  ' * nn
    #TT.debug "#{tab}find_optimal_quad_solution(#{nn})"
    #TT.debug "#{tab}> s1: #{s1.size}"
    #TT.debug "#{tab}> s2: #{s2.size}"
    
    # Is both solutions yield the same amount of quads, pick the one that uses
    # the most of the origin quadface's neighbouring faces.
    if s1.size == s2.size
      s1_faces = s1.map { |qf| qf.faces }.flatten
      s2_faces = s2.map { |qf| qf.faces }.flatten
      s1_remaining = ( neighbours - s1_faces ).size
      s2_remaining = ( neighbours - s2_faces ).size
      #TT.debug ">> #{( s1_remaining < s2_remaining ) ? 's1' : 's2'}"
      # (!) There are cases where the choice is 50/50 as the remaining triangles
      #     are not connected to the origin.
      if s1_remaining == s2_remaining
        # Try to infer the correct choice.
        # Currently compares the total length of the edges in each solution.
        # The one with the shortest length is more likely to be the most
        # appropriate.
        s1_edges = s1.map { |qf| qf.edges }.flatten
        s2_edges = s2.map { |qf| qf.edges }.flatten
        s1_length = s1_edges.inject(0) { |sum, edge| sum + edge.length } #|| 0
        s2_length = s2_edges.inject(0) { |sum, edge| sum + edge.length } #|| 0
        ( s1_length < s2_length ) ? s1 : s2
      else
        ( s1_remaining < s2_remaining ) ? s1 : s2
      end
      #( s1_remaining <= s2_remaining ) ? s1 : s2
    else
      #TT.debug ">> #{( s1.size > s2.size ) ? 's1' : 's2'}"
      ( s1.size > s2.size ) ? s1 : s2
    end
  end
  
  
  # @param [QuadFace] origin
  # @param [Array<QuadFace>] existing
  # @param [Array<Sketchup::Face>] tagged
  # @param [Array<Sketchup::Face>] neighbours
  # @param [Sketchup::Face] face1
  # @param [Sketchup::Face] face2
  #
  # @return [<Array<VirtualQuadFace>]
  # @since 0.1.0
  def self.find_possible_quads( quadface_origin, existing, tagged, neighbours, face1, face2, nn=0 )
    tagged = tagged.dup # Ensure a local copy.
    start = VirtualQuadFace.new( face1, face2 )
    
    #start.material = 'Plum'
    
    tagged << face1
    tagged << face2
    
    quadfaces = [ start ]
    stack = [ start ]
    until stack.empty?
      quadface = stack.shift
      # No point looking if there are no more neighbouring faces left to
      # process.
      break if (neighbours-tagged).size == 0 # (?)
      # Find neighbour faces to current quadface and origin.
      for edge in quadface.edges
        for face in edge.faces
          next unless neighbours.include?( face )
          next if tagged.include?( face )
          next unless face.vertices.size == 3
          
          unless ( quadface_origin.edges & face.edges ).size == 1
            # Shares only a vertex with origin.
            
            edges = face.edges - quadface.edges
            f1, f2 = edges.map { |e| ( e.faces - [face] )[0] }
            
            #next
            solution = self.find_optimal_quad_solution(
              quadface_origin, existing+quadfaces, tagged, neighbours, face, f1, f2, nn+1 )
              
            #tab = '  ' * nn
            #TT.debug "#{tab}find_possible_quads(#{nn}): #{solution.size}"
              
            # Add data to current data set.
            quadfaces.concat( solution )
            stack.concat( solution )
            for virtual_face in solution
              tagged.concat( virtual_face.faces )
            end
            # Done processing this face.
            next
          end
          # Shared edge with origin - quadface is a corner.
          divider = ( face.edges - quadface.edges - quadface_origin.edges )[0]
          other_triangle = ( divider.faces - [ face ] )[0]
          next unless other_triangle
          next unless other_triangle.vertices.size == 3
          next if QuadFace.is?( other_triangle )
          next if tagged.include?( other_triangle )
          new_quadface = VirtualQuadFace.new( face, other_triangle )
          #new_quadface.material = 'cyan'
          tagged.concat( new_quadface.faces )
          quadfaces << new_quadface
          stack << new_quadface
        end
      end
    end # until
    quadfaces
    valid = self.valid_solution?( quadface_origin, quadfaces + existing )
    
=begin
    sel = Sketchup.active_model.selection
    cache = sel.to_a
    sel.clear
    faces = quadfaces.map { |qf| qf.faces }.flatten
    sel.add( faces )
    sel.add( face1.edges )
    
    existing.each { |qf| qf.material = 'cyan' }
    
    result = UI.messagebox( "#{face1} (#{nn})\nExisting: #{existing.size}\nPossible Solution (#{quadfaces.size})\nValid: #{valid}", MB_OK )
    sel.clear
    sel.add( cache )
=end
    
    #str =  (valid) ? "find_possible_quads: #{quadfaces.size}" : "find_possible_quads: INVALID (#{quadfaces.size})"
    #TT.debug "#{('  ')*nn} #{str}"
    valid ? quadfaces : []
  end
  
  
  # @param [QuadFace] quadface_origin
  # @param [Array<QuadFace>] solution
  #
  # @return [Boolean]
  # @since 0.1.0
  def self.valid_solution?( quadface_origin, solution )
   # TT.debug 'self.valid_solution?'
    if solution.size > 8
      #TT.debug "> INVALID solution - size: #{solution.size}"
      return false 
    end
    for vertex in quadface_origin.vertices
      faces = solution.select { |quadface|
        quadface.vertices.include?( vertex )
      }
      if faces.size > 3
        #TT.debug "> INVALID solution - Corner Quads: #{faces.size}"
        return false
      end
    end
    true
  end
  
end # module