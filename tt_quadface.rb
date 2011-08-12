#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.6.0', 'TT QuadFace Tools')

#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  ID          = 'TT_QuadFaceTools'.freeze
  VERSION     = TT::Version.new(0,1,0).freeze
  PLUGIN_NAME = 'QuadFace Tools'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH        = File.join( PATH_ROOT, 'TT_QuadFaceTools' ).freeze
  PATH_ICONS  = File.join( PATH, 'Icons' ).freeze
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( File.basename(__FILE__) )
    # Commands
    cmd = UI::Command.new( 'Select' )   { self.select_quadface_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Select_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Select_24.png' )
    cmd.status_bar_text = 'Select Tool.'
    cmd.tooltip = 'Select'
    cmd_select = cmd
    
    cmd = UI::Command.new( 'Grow Selection' ) { self.selection_grow }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionGrow_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionGrow_24.png' )
    cmd.status_bar_text = 'Grow Selection.'
    cmd.tooltip = 'Grow Selection'
    cmd_selection_grow = cmd
    
    cmd = UI::Command.new( 'Shrink Selection' ) { self.selection_shrink }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionShrink_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionShrink_24.png' )
    cmd.status_bar_text = 'Shrink Selection.'
    cmd.tooltip = 'Shrink Selection'
    cmd_selection_shrink = cmd
    
    cmd = UI::Command.new( 'Ring' ) { self.select_rings }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectRing_24.png' )
    cmd.status_bar_text = 'Select Ring.'
    cmd.tooltip = 'Select Ring'
    cmd_select_ring = cmd
    
    cmd = UI::Command.new( 'Grow Ring' )  { self.select_rings( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowRing_24.png' )
    cmd.status_bar_text = 'Grow Ring.'
    cmd.tooltip = 'Grow Ring'
    cmd_grow_ring = cmd
    
    cmd = UI::Command.new( 'Shrink Ring' )  { self.select_rings( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkRing_24.png' )
    cmd.status_bar_text = 'Shrink Ring.'
    cmd.tooltip = 'Shrink Ring'
    cmd.set_validation_proc { MF_GRAYED }
    cmd_shrink_ring = cmd
    
    cmd = UI::Command.new( 'Loop' ) { self.select_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectLoop_24.png' )
    cmd.status_bar_text = 'Select Loop.'
    cmd.tooltip = 'Select Loop'
    cmd_select_loop = cmd
    
    cmd = UI::Command.new( 'Grow Loop' )  { self.select_loops( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowLoop_24.png' )
    cmd.status_bar_text = 'Grow Loop.'
    cmd.tooltip = 'Grow Loop'
    cmd_grow_loop = cmd
    
    cmd = UI::Command.new( 'Shrink Loop' )  { self.select_loops( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkLoop_24.png' )
    cmd.status_bar_text = 'Shrink Loop.'
    cmd.tooltip = 'Shrink Loop'
    cmd.set_validation_proc { MF_GRAYED }
    cmd_shrink_loop = cmd
    
    cmd = UI::Command.new( 'Triangulate' )  { self.triangulate_selection}
    cmd.small_icon = File.join( PATH_ICONS, 'Triangulate_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Triangulate_24.png' )
    cmd.status_bar_text = 'Triangulate selected QuadFaces.'
    cmd.tooltip = 'Triangulate Selected QuadFaces'
    cmd_triangulate_selection = cmd
    
    cmd = UI::Command.new( 'Convert Connected to Quads' )  {
      self.convert_connected_mesh_to_quads
    }
    cmd.small_icon = File.join( PATH_ICONS, 'ConvertToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ConvertToQuads_24.png' )
    cmd.status_bar_text = 'Convert connected geometry to Quads.'
    cmd.tooltip = 'Convert Connected to Quads'
    cmd_convert_connected_mesh_to_quads = cmd
    
    # Menus
    m = TT.menu( 'Tools' ).add_submenu( 'QuadFace Tools' )
    m.add_item( cmd_select )
    m.add_separator
    m.add_item( cmd_selection_grow )
    m.add_item( cmd_selection_shrink )
    m.add_separator
    m.add_item( cmd_select_ring )
    m.add_item( cmd_grow_ring )
    m.add_item( cmd_shrink_ring )
    m.add_separator
    m.add_item( cmd_select_loop )
    m.add_item( cmd_grow_loop )
    m.add_item( cmd_shrink_loop )
    m.add_separator
    m.add_item( cmd_triangulate_selection )
    m.add_item( cmd_convert_connected_mesh_to_quads )
    
    # Context menu
    #UI.add_context_menu_handler { |context_menu|
    #  model = Sketchup.active_model
    #  selection = model.selection
    #  # ...
    #}
    
    # Toolbar
    toolbar = UI::Toolbar.new( PLUGIN_NAME )
    toolbar.add_item( cmd_select )
    toolbar.add_separator
    toolbar.add_item( cmd_selection_grow )
    toolbar.add_item( cmd_selection_shrink )
    toolbar.add_separator
    toolbar.add_item( cmd_select_ring )
    toolbar.add_item( cmd_grow_ring )
    toolbar.add_item( cmd_shrink_ring )
    toolbar.add_separator
    toolbar.add_item( cmd_select_loop )
    toolbar.add_item( cmd_grow_loop )
    toolbar.add_item( cmd_shrink_loop )
    toolbar.add_separator
    toolbar.add_item( cmd_triangulate_selection )
    toolbar.add_item( cmd_convert_connected_mesh_to_quads )
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @since 0.1.0
  def self.select_quadface_tool
    Sketchup.active_model.select_tool( SelectQuadFace.new )
  end
  
  
  # @since 0.1.0
  def self.triangulate_selection
    model = Sketchup.active_model
    selection = model.selection
    new_selection = []
    TT::Model.start_operation( 'Triangulate QuadFaces' )
    for entity in selection.to_a
      next unless entity.is_a?( Sketchup::Face )
      next unless QuadFace.is?( entity )
      quadface = QuadFace.new( entity )
      quadface.triangulate!
      new_selection.concat( quadface.faces )
    end
    model.commit_operation
    selection.add( new_selection )
  end
  
  
  # @since 0.1.0
  def self.select_rings( step = false )
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      entities.concat( find_edge_ring( entity, step ) )
    end
    # Select
    selection.add( entities )
  end
  
  
  # @since 0.1.0
  def self.select_loops( step = false )
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      entities.concat( find_edge_loop( entity, step  ) )
    end
    # Select
    selection.add( entities )
  end
  
  
  # @since 0.1.0
  def self.selection_grow
    selection = Sketchup.active_model.selection
    new_selection = []
    for entity in selection
      if entity.is_a?( Sketchup::Edge )
        for vertex in entity.vertices
          edges = vertex.edges.select { |e| !QuadFace.dividing_edge?( e ) }
          new_selection.concat( edges )
        end
      elsif entity.is_a?( Sketchup::Face )
        if QuadFace.is?( entity )
          face = QuadFace.new( entity )
        else
          face = entity
        end
        for edge in face.edges
          for f in edge.faces
            if QuadFace.is?( f )
              qf = QuadFace.new( f )
              new_selection.concat( qf.faces )
            else
              new_selection << f
            end
          end
        end # for edge in face.edges
      end # if entity.is_a?
    end # for entity
    # Update selection
    selection.add( new_selection )
  end
  
  
  # @since 0.1.0
  def self.selection_shrink
    selection = Sketchup.active_model.selection
    new_selection = []
    for entity in selection
      if entity.is_a?( Sketchup::Edge )
        unless entity.vertices.all? { |vertex|
          edges = vertex.edges.select { |e| !QuadFace.dividing_edge?( e ) }
          edges.all? { |edge| selection.include?( edge ) }
        }
          new_selection << entity
        end
      elsif entity.is_a?( Sketchup::Face )
        unless entity.edges.all? { |edge|
          edge.faces.all? { |face|
            if QuadFace.is?( face )
              qf = QuadFace.new( face )
              qf.faces.any? { |f| selection.include?( f ) }
            else
              selection.include?( face )
            end
          }
        }
          if QuadFace.is?( entity )
            qf = QuadFace.new( entity )
            new_selection.concat( qf.faces )
          else
            new_selection << entity
          end
        end
      end # if entity.is_a?
    end # for entity
    # Update selection
    selection.remove( new_selection )
  end
  
  
  # @since 0.1.0
  def self.process_entity( entity )
    if entity.is_a?( Sketchup::Face ) && QuadFace.is?( entity )
      entity = QuadFace.new( entity )
    end
    entity
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.find_edge_ring( origin_edge, step = false )
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?( Sketchup::Edge )
    # Find initial connected QuadFaces
    return false unless ( 1..2 ).include?( origin_edge.faces.size )
    valid_faces = origin_edge.faces.select { |f| QuadFace.is?( f ) }
    quads = valid_faces.map { |face| QuadFace.new( face ) }
    # Find ring loop
    selected_faces = []
    selected_edges = [ origin_edge ]
    for quad in quads
      current_quad = quad
      current_edge = current_quad.opposite_edge( origin_edge )
      until current_edge.nil?
        selected_faces << current_quad
        selected_edges << current_edge
        break if step
        # Look for more connected.
        current_quad = current_quad.next_face( current_edge )
        break unless current_quad # if nil
        current_edge = current_quad.opposite_edge( current_edge )
        # Stop if the entities has already been processed.
        break if selected_edges.include?( current_edge )
      end
    end
    selected_edges
  end
  
  
  # Selects a loop of edges. Loop can be grown in steps.
  #
  # Currently using the Blender method - with exception of edges with no faces. 
  #
  #
  # Blender
  #
  # Blender 2.58a
  # editmesh_mods.c
  # Line 1854
  #
  # selects or deselects edges that:
  # - if edges has 2 faces:
  #   - has vertices with valence of 4
  #   - not shares face with previous edge
  # - if edge has 1 face:
  #   - has vertices with valence 4
  #   - not shares face with previous edge
  #   - but also only 1 face
  # - if edge no face:
  #   - has vertices with valence 2
  #
  #
  # In Maya, an edge loop has the following properties: 
  # * The vertices that connect the edges must have a valency equal to four.
  #   Valency refers to the number of edges connected to a particular vertex.
  # * The criteria for connecting the sequence is that the next edge in the
  #   sequence is the (i + 2nd) edge of the shared vertex, determined in order
  #   from the current edge (i).
  # * The sequence of edges (loop) can form either an open or closed path on the
  #   polygonal mesh.
  # * The start and end edges need not have a valency equal to four.
  #
  # @see http://download.autodesk.com/global/docs/maya2012/en_us/index.html?url=files/Polygon_selection_and_creation_Select_an_edge_loop.htm,topicNumber=d28e121344
  #
  #
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.find_edge_loop( origin_edge, step = false )
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?( Sketchup::Edge )
    # Find initial connected faces
    face_count = origin_edge.faces.size
    return false unless ( 1..2 ).include?( face_count )
    faces = self.connected_faces( origin_edge )
    # Find existing entities affecting the loop.
    selected_edges = origin_edge.model.selection.select { |e| e.is_a?( Sketchup::Edge ) }    
    # Find edge loop.
    step_limit = 0
    loop = []
    stack = [ origin_edge ]
    until stack.empty?
      edge = stack.shift
      # Find connected edges
      next_vertices = []
      for v in edge.vertices
        edges = v.edges.select { |e| !e.soft? }
        next if edges.size > 4 # Stop at forks
        next if edges.any? { |e| loop.include?( e ) }
        next_vertices << v
      end
      # Add to loop
      loop << edge
      # Get connected faces
      faces.concat( self.connected_faces( edge ) )
      # Pick next edges
      valid_edges = 0
      for vertex in next_vertices
        for e in vertex.edges
          next if e == edge
          next if e.soft? # Ignore QuadFace diagonals. Requires un-smooth loop.
          next if faces.any? { |f| f.edges.include?( e ) }
          next if loop.include?( e )
          next if selected_edges.include?( e ) # (?) Needed?
          next unless e.faces.size == face_count
          valid_edges += 1
          stack << e
        end # for e
      end # for vertex
      # Stop if the loop is step-grown.
      if step
        step_limit = valid_edges if edge == origin_edge
        break if loop.size > step_limit
      end
    end # until
    loop
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Face,QuadFace>]
  # @since 0.1.0
  def self.connected_faces( edge )
    faces = []
    for face in edge.faces
      if QuadFace.is?( face )
        faces << QuadFace.new( face )
      else
        faces << face
      end
    end
    faces
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<QuadFace>]
  # @since 0.1.0
  def self.connected_quad_faces( edge )
    # Get connected faces
    valid_faces = edge.faces.select { |f| QuadFace.is?( f ) }
    quads = valid_faces.map { |face| QuadFace.new( face ) }
  end
  
  
  # @since 0.1.0
  def self.transform
    # (!)
    # Transform a set of entities related to quadfaces - ensuring that native
    # quadfaces are triangulated correctly with a soft & smooth divider edge.
  end
  
  
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
      if i > 5000
        puts "LOOP!"
        UI.beep
        break
      end
      # </debug>
      
      quad = stack.shift
      next if ( tagged & quad.faces ).size > 0
      
      j+=1 # <debug/>
      
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
  
  # TT::Plugins::QuadFaceTools.reload
  #
  # @since 0.1.0
  def self.find_connected_quadfaces( quadface_origin )
    # Find confirmed quadfaces connected each vertex. (Native or QuadFace)
    faces = [] # Unconfirmed
    quadfaces = [] # Confirmed
    tagged = quadface_origin.faces # Faces processed.
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
  
  
  # @return [<Array<VirtualQuadFace>]
  # @since 0.1.0
  def self.find_optimal_quad_solution( origin, existing, tagged, neighbours, source, face1, face2, nn=0 )
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
  
  
  # @since 0.1.0
  def self.common_edge( triangle1, triangle2 )
    intersect = triangle1.edges & triangle2.edges
    return nil if intersect.empty?
    intersect[0]
  end
  
  
  # @since 0.1.0
  def self.valid_triangles( faces, ignore_quads )
    # Ignore processed quads.
    faces.reject! { |face|
      ignore_quads.any?{ |quadface| quadface.faces.include?( face ) }
    }
    # Choose a triangle
    faces.select { |face| face.vertices.size == 3 }
  end
  
  
  # @since 0.1.0
  def self.next_triangle( faces, ignore_quads )
    # Ignore processed quads.
    faces.reject! { |face|
      ignore_quads.any?{ |quadface| quadface.faces.include?( face ) }
    }
    # Choose a triangle
    for face in faces
      return face if face.vertices.size == 3
    end
    nil
  end
  
  
  # @since 0.1.0
  def self.at_corner?( quadface_origin, quadface )
    quadface_origin.edges.any? { |edge|
      quadface.edges.include?( edge )
    }
  end
  
  
  # @since 0.1.0
  def self.corner_vertex( quadface_origin, quadface )
    intersect = quadface_origin.vertices & quadface.vertices
    ( intersect.empty? ) ? nil : intersect[0]
  end
  
  
  # @return [QuadFace]
  # @since 0.1.0
  def self.find_other_triangle( triangle, shared_edge, connected_quadface )
    # (!) Not perfect. In some cases it picks the least matching edge.
    #     Maybe - instead of looking for a best bet for once triangle - 
    #     it would be better to take the origin quadface, analyse each
    #     connected faces at each vertex and run multiple passes and choose
    #     the pass the produces the most quadfaces?
    #
    # Narrow down options
    edges = triangle.edges - [ shared_edge ]
    # Find possible faces
    faces = []
    for edge in edges
      next unless edge.faces.size == 2
      for face in edge.faces
        next unless face.vertices.size == 3
        next if face == triangle
        next if connected_quadface.faces.include?( face )
        next if QuadFace.is?( face )
        faces << face
      end
    end
    # Find best match
    return nil if faces.empty?
    if faces.size == 1
      faces[0].material = 'green' # DEBUG (certain choice)
      return faces[0]
    else
      # Work out which of the two likely faces is the best fit for a QuadFace.
      #
      # Find perpendicular edges to `edge` in `connected_quadface`.
      loop = connected_quadface.outer_loop
      index = loop.index( shared_edge )
      prev_edge_index = ( index - 1 ) % 4
      next_edge_index = ( index + 1 ) % 4
      prev_edge = loop[ prev_edge_index ]
      next_edge = loop[ next_edge_index ]
      # Find edges in possible faces that connects to `edge`
      possible_edges = []
      for face in faces
        edges = face.edges - triangle.edges
        for edge in edges
          if self.edges_connected?( edge, shared_edge )
            possible_edges << edge
          end
        end
      end
      raise "> possible edges: #{possible_edges.size}" unless possible_edges.size == 2
      # Find edge in `triangle` that is the most colinear match.
      # (!) Bug - See Bug01.png
      best_angle = nil
      best_match = nil
      for quad_edge in [ prev_edge, next_edge ]
        for tri_edge in possible_edges
          next unless self.edges_connected?( quad_edge, tri_edge )
          # Get vectors running in the same direction through the shared edge.
          vertex = TT::Edges.common_vertex( quad_edge, tri_edge )
          v1 = vertex.position.vector_to( quad_edge.other_vertex( vertex ).position ).reverse
          v2 = vertex.position.vector_to( tri_edge.other_vertex( vertex ).position )
          # Measure angle
          angle = v1.angle_between( v2 )
          if best_angle.nil? || angle < best_angle
            best_angle = angle
            best_match = tri_edge
          end
        end
      end
      # Use the remaining edge in `triangle` as the divider.
      if triangle.edges.include?( best_match )
        divider = ( triangle.edges - [ shared_edge, best_match ] )[0]
        other_triangle = ( divider.faces & faces )[0]
      else
        other_triangle = ( best_match.faces & faces )[0]
      end
      other_triangle.material = 'orange' # DEBUG (uncertain choice)
      return other_triangle
    end
    nil
  end
  
  
  # @return [QuadFace]
  # @since 0.1.0
  def self.edges_connected?( edge1, edge2 )
    edge1.vertices.any? { |vertex| edge2.vertices.include?( vertex ) }
  end
  
  
  # @return [QuadFace]
  # @since 0.1.0
  def self.convert_to_quad( *args )
    if args.size == 1
      face = args[0]
      for edge in face.edges
        if edge.soft?
          edge.soft = false
          edge.hidden = true
        end
      end
      QuadFace.new( face )
    elsif args.size == 3
      face1, face2, dividing_edge = args
      dividing_edge.soft = true
      dividing_edge.smooth = true
      for face in [ face1, face2 ]
        for edge in face.edges
          next if edge == dividing_edge
          if edge.soft?
            edge.soft = false
            edge.hidden = true
          end
        end
      end
      QuadFace.new( face1 )
    else
      raise ArgumentError, 'Incorrect number of arguments.'
    end
  end
  
  
  # (!) Custom QuadFaceEdge class for smarter traversing of the QuadFace mesh.
  
  # @since 0.1.0
  class QuadFaceEdge
    
    # @param [Sketchup::Edge] edge
    #
    # @since 0.1.0
    def initialize( edge )
      raise ArgumentError, 'Invalid Edge' unless edge.is_a?( Sketchup::Edge )
      @edge = edge
      @faces = []
    end
    
    # @param [QuadFace] face
    #
    # @since 0.1.0
    def link_face( face )
      raise ArgumentError, 'Invalid QuadFace' unless face.is_a?( QuadFace )
      @faces << face unless @faces.include?( face )
    end
    
    # @param [QuadFace] face
    #
    # @since 0.1.0
    def unlink_face( face )
      raise ArgumentError, 'Invalid QuadFace' unless face.is_a?( QuadFace )
      @faces.delete( face )
    end
    
  end # class QuadFaceEdge

  
  # Wrapper class for making handling of quad faces easier. Since a quad face
  # might be triangulated, this class allows the possibly multiple native
  # SketchUp entities to be treated as one object.
  #
  # A QuadFace is defined as:
  # * A face with four vertices bound by non-soft edges.
  # * Two triangular faces joined by a soft edge bound by non-soft edges.
  #
  # @since 0.1.0
  class QuadFace
    
    # Evaluates if the entity is a face that forms part of a QuadFace.
    #
    # @see {QuadFace}
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.is?( entity )
      return false unless entity.is_a?( Sketchup::Face )
      face = entity
      return false unless (3..4).include?( face.vertices.size )
      soft_edges = face.edges.select { |e| e.soft? }
      if face.vertices.size == 3
        # Triangulated QuadFace
        return false unless soft_edges.size == 1
        dividing_edge = soft_edges[0]
        return false unless dividing_edge.faces.size == 2
        other_face = ( dividing_edge.faces - [face] ).first
        soft_edges = other_face.edges.select { |e| e.soft? }
        return false unless soft_edges.size == 1
      else # face.vertices.size == 4
        # Pure Quadface
        return false if soft_edges.size > 0
      end
      true
    end
    
    # Evaluates if the entity is a face that forms part of a QuadFace.
    #
    # @see {QuadFace}
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.dividing_edge?( entity )
      return false unless entity.is_a?( Sketchup::Edge )
      edge = entity
      return false unless edge.soft?
      return false unless edge.faces.size == 2
      edge.faces.all? { |face| self.is?( face ) }
    end
    
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.valid_geometry?( *args )
      # Validate arguments
      unless (1..2).include?( args.size )
        raise ArgumentError, 'Must be one or two faces.'
      end
      unless args.all? { |e| e.is_a?( Sketchup::Face ) }
        raise ArgumentError, 'Must be faces.'
      end
      # Validate geometric properties
      if args.size == 1
        # Native QuadFace
        face = args[0]
        return false unless face.vertices.size == 4
      else
        # Triangulated QuadFace
        face1, face2 = args
        return false unless face1.vertices.size == 3
        return false unless face2.vertices.size == 3
        return false unless face1.edges.any? { |e| face2.edges.include?( e ) }
      end
      true
    end
    
    # @param [Sketchup::Face] face
    #
    # @since 0.1.0
    def initialize( face )
      unless valid_native_face?( face )
        raise ArgumentError, 'Invalid QuadFace'
      end
      @faces = [ face ]
      # Check if the quadface is triangualted.
      face2 = other_native_face( face )
      @faces << face2 if face2.is_a?( Sketchup::Face )
    end
    
    # @param [QuadFace] quadface
    #
    # @return [Sketchup::Edge,Nil]
    # @since 0.1.0
    def common_edge( quadface )
      unless quadface.is_a?( QuadFace )
        raise ArgumentError, 'Invalid QuadFace'
      end
      other_edges = quadface.edges
      match = edges.select { |edge| other_edges.include?( edge ) }
      return nil unless match
      match[0]
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.1.0
    def edges
      result = []
      for face in @faces
        result.concat( face.edges.select { |e| !e.soft? } )
      end
      result
    end
    
    # @return [Array<Sketchup::Face>]
    # @since 0.1.0
    def faces
      @faces.dup
    end
    
    # @param [Sketchup::Face] face
    #
    # @return [Boolean]
    # @since 0.1.0
    def include?( face )
      @faces.include?( face )
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      name = self.class.name.split('::').last
      hex_id = TT.object_id_hex( self )
      "#<#{name}:#{hex_id}>"
    end
    
    # @return [Geom::PolygonMesh]
    # @since 0.1.0
    def mesh
      if @faces.size == 1
        @faces[0].mesh
      else
        face1, face2 = @faces
        pm1 = face1.mesh
        pm2 = face2.mesh
        # Merge the polygon from face2 with face1.
        # (i) This assumes @faces contains two valid triangular faces.
        polygon = pm2.polygon_points_at( 1 )
        pm1.add_polygon( *polygon )
        pm1
      end
    end
    
    # @return [QuadFace,Nil]
    # @since 0.1.0
    def next_face( edge )
      return nil unless edge.faces.size == 2
      quadfaces = edge.faces.reject! { |face| @faces.include?( face ) }
      return nil if quadfaces.empty?
      return nil unless valid_native_face?( quadfaces[0] )
      QuadFace.new( quadfaces[0] )
    end
    
    # @return [Sketchup::Material]
    # @since 0.1.0
    def material=( material )
      for face in @faces
        face.material = material
      end
      face.material
    end
    
    # @return [Sketchup::Edge]
    # @since 0.1.0
    def opposite_edge( edge )
      edges = outer_loop()
      index = edges.index( edge )
      unless index
        raise ArgumentError, 'Edge not part of QuadFace loop.'
      end
      other_index = ( index + 2 ) % 4
      edges[ other_index ]
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.1.0
    def outer_loop
      TT::Edges.sort( edges )
    end
    
    # @return [Boolean]
    # @since 0.1.0
    def triangulated?
      @faces.size > 1
    end
    
    # @return [Boolean]
    # @since 0.1.0
    def triangulate!
      if @faces.size == 1
        # (?) Validation required?
        face = @faces[0]
        entities = face.parent.entities
        mesh = face.mesh
        # Find the splitting segment.
        polygon1 = mesh.polygon_at( 1 ).map{ |i| i.abs }
        polygon2 = mesh.polygon_at( 2 ).map{ |i| i.abs }
        split = polygon1 & polygon2
        # Add edge at split
        split.map! { |index| mesh.point_at( index ) }
        edge = entities.add_line( *split )
        edge.soft = true
        edge.smooth = true
        # Update references
        @faces = edge.faces
      else
        false
      end
    end
    
    # @return [Array<Sketchup::Vertices>]
    # @since 0.1.0
    def vertices
      outer_loop.map { |edge| edge.vertices }.flatten.uniq
    rescue
      faces.each { |e| e.material = 'orange' }
      edges.each { |e| e.material = 'red' }
      p edges
      p outer_loop
      raise
    end
    
    private
    
    # @param [Sketchup::Face] face
    #
    # @return [Sketchup::Face]
    # @since 0.1.0
    def other_native_face( face )
      return nil unless face.vertices.size == 3
      soft_edges = face.edges.select { |e| e.soft? }
      return nil unless soft_edges.size == 1
      dividing_edge = soft_edges[0]
      return nil unless dividing_edge.faces.size == 2
      ( dividing_edge.faces - [face] ).first
    end
    
    # @param [Sketchup::Face] face
    #
    # @return [Boolean]
    # @since 0.1.0
    def valid_native_face?( face )
      return false unless face.is_a?( Sketchup::Face )
      return false unless (3..4).include?( face.vertices.size )
      # Check for bordering soft edges. Triangulated QuadFaces should have one
      # soft edge - where it joins the other triangle.
      # Native quads should have none.
      if face.vertices.size == 3
        # Triangulated QuadFace
        face2 = other_native_face( face )
        return false unless face2
      else # face.vertices.size == 4
        # Pure Quadface
        soft_edges = face.edges.select { |e| e.soft? }
        return false if soft_edges.size > 0
      end
      true
    end
  
  end # class Quadface
  
  
  # @since 0.1.0
  class VirtualQuadFace < QuadFace
  
    # @param [Sketchup::Face] face
    #
    # @since 0.1.0
    def initialize( triangle1, triangle2 )
      unless triangle1.is_a?( Sketchup::Face ) && triangle2.is_a?( Sketchup::Face )
        raise ArgumentError, 'Invalid faces.'
      end
      @faces = [ triangle1, triangle2 ]
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.1.0
    def edges
      triangle1, triangle2 = @faces
      divider = triangle1.edges & triangle2.edges
      ( triangle1.edges + triangle2.edges ) - divider
    end
    
  end # class VirtualQuadFace
  
  
  # @since 0.1.0
  class SelectQuadFace
    
    # @since 0.1.0
    def initialize
      model = Sketchup.active_model
      # Find QuadFaces
      @faces = model.active_entities.select { |e| QuadFace.is?( e ) }
      # (!) Build QuadFace list
      # Build draw cache
      @edges = @faces.map { |quad| quad.edges }
      @edges.flatten!
      @edges.uniq!
      @edges.reject! { |e| e.soft? }
      @segments = @edges.map { |e| [e.start.position, e.end.position] }
      @lines = @segments.flatten
      # Used by onSetCursor
      @key_ctrl = false
      @key_shift = false
      
      @cursor         = TT::Cursor.get_id( :select )
      @cursor_add     = TT::Cursor.get_id( :select_add )
      @cursor_remove  = TT::Cursor.get_id( :select_remove )
      @cursor_toggle  = TT::Cursor.get_id( :select_toggle )
    end
    
    # @since 0.1.0
    def activate
      Sketchup.active_model.active_view.invalidate
    end
    
    # @since 0.1.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.1.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.1.0
    def onLButtonDown( flags, x, y, view )
      ph = view.pick_helper
      picked_edge = nil
      picked_quad = nil
      # Pick faces
      ph.do_pick( x, y )
      entity = ph.picked_face
      if entity && @faces.include?( entity )
        quad = QuadFace.new( entity )
        picked_quad = quad
      end
      # Pick Edges
      # Hidden edges are not picked if Hidden Geometry is off.
      ph.init( x, y )
      for edge in @segments
        result = ph.pick_segment( edge )
        next unless result
        # Find the edge which the segment represented.
        index = @segments.index( edge )
        current_edge = @edges[index]
        if picked_quad
          # If a quad has been picked, choose edge connected to the quad - if
          # possible.
          if picked_quad.edges.include?( current_edge )
            picked_edge = current_edge
            break
          end
        else
          picked_edge = current_edge
          break
        end
      end
      # Determine what to pick.
      picked = nil
      if picked_edge
        picked = picked_edge
      elsif picked_quad
        picked = picked_quad.faces
      end
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      # Select the entities.
      entities = []
      entities << picked if picked
      selection = view.model.selection
      if key_ctrl && key_shift
        selection.remove( entities )
      elsif key_ctrl
        selection.add( entities )
      elsif key_shift
        selection.toggle( entities )
      else
        selection.clear
        selection.add( entities )
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyDown
    #
    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyUp
    #
    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor()
      false
    end
    
    # @since 0.1.0
    def draw( view )
      unless @lines.empty?
        view.line_stipple = ''
        view.line_width = 3
        view.drawing_color = 'red'
        view.draw_lines( @lines )
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onSetCursor
    #
    # @since 1.0.0
    def onSetCursor
      if @key_ctrl && @key_shift
        cursor = @cursor_remove
      elsif @key_ctrl
        cursor = @cursor_add
      elsif @key_shift
        cursor = @cursor_toggle
      else
        cursor = @cursor
      end
      UI.set_cursor( cursor )
    end
    
  end # class QuadFaceInspector
  
  
  ### DEBUG ### ----------------------------------------------------------------  
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::QuadFaceTools.reload
  #
  # @param [Boolean] tt_lib
  #
  # @return [Integer]
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    #x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
    #  load file
    #}
    #x.length
  ensure
    $VERBOSE = original_verbose
  end
  
end # module

#-------------------------------------------------------------------------------

file_loaded( File.basename(__FILE__) )

#-------------------------------------------------------------------------------