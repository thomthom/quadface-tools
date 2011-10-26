#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # Custom Exceptions
  
  # @since 0.2.0
  class InvalidQuadFace < StandardError; end
  
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
    
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.4.0
    def self.divider_props?( edge )
      return false unless edge.soft?
      return false unless edge.smooth?
      return false unless edge.hidden?
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
    def self.dividing_edge?( edge )
      return false unless edge.is_a?( Sketchup::Edge )
      return false unless self.divider_props?( edge )
      return false unless edge.faces.size == 2
      return false unless edge.faces.all? { |face| face.vertices.size == 3 }
      edge.faces.all? { |face| self.is?( face ) }
    end
    
    # Evaluates if the edge is part of a QuadFace.
    #
    # @param [Sketchup::Edge,Sketchup::Vertex] entity
    #
    # @return [Boolean]
    # @since 0.4.0
    def self.entity_in_quad?( entity )
      entity.faces.any? { |face| self.is?( face ) }
    end
    
    # @param [Array<Sketchup::Vertex>] vertices
    #
    # @return [QuadFace,Nil]
    # @since 0.4.0
    def self.from_vertices( vertices )
      return nil unless vertices.size == 4
      vertex = vertices.first
      face = vertex.faces.find { |f|
        f.vertices.all? { |v| vertices.include?( v ) }
      }
      return nil unless face
      return nil unless self.is?( face )
      quad = self.new( face )
      return nil unless quad.vertices.all? { |v| vertices.include?( v ) }
      quad
    end
    
    # Evaluates if the entity is a face that forms part of a QuadFace.
    #
    # @see {QuadFace}
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.is?( face )
      return false unless face.is_a?( Sketchup::Face )
      return false unless face.valid?
      vertex_count = face.vertices.size
      return false if vertex_count < 3
      return false if vertex_count > 4
      # Triangulated QuadFace needs special treatment.
      if vertex_count == 3
        edges = face.edges.select { |e| self.divider_props?( e ) }
        return false unless edges.size == 1
        dividing_edge = edges[0]
        return false unless dividing_edge.faces.size == 2
        other_face = ( dividing_edge.faces - [face] ).first
        return false unless other_face.vertices.size == 3
        edges = other_face.edges.select { |e| self.divider_props?( e ) }
        return false unless edges.size == 1
      end
      true
    end
    
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.valid_geometry?( *args )
      # (?) Unused?
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
    
    # @param [Sketchup::Edge] edge
    #
    # @return [Sketchup::Edge]
    # @since 0.4.0
    def self.set_border_props( edge )
      if edge.soft? && edge.smooth? && edge.hidden?
        edge.hidden = false
      end
      edge
    end
    
    # @param [Sketchup::Edge] edge
    #
    # @return [Sketchup::Edge]
    # @since 0.4.0
    def self.set_divider_props( edge )
      edge.soft = true
      edge.smooth = true
      edge.hidden = true
      edge
    end
    
    # @param [Sketchup::Edge] edge
    #
    # @return [Sketchup::Edge]
    # @since 0.6.0
    def self.smooth_edge( edge )
      if edge.faces.size > 1
        edge.soft = true
        edge.smooth = true
        edge.hidden = false
      end
      edge
    end
    
    # @param [Sketchup::Edge] edge
    #
    # @return [Sketchup::Edge]
    # @since 0.6.0
    def self.unsmooth_edge( edge )
      edge.soft = false
      edge.smooth = false
      edge.hidden = false
      edge
    end
    
    # @param [Sketchup::Face] face
    #
    # @since 0.1.0
    def initialize( face )
      # (!) The creating of a QuadFace is slow. Improve.
      #     Remove validations. Assume valid input. Make valid?
      #     verify validity of quads.
      unless face2 = valid_native_face?( face )
        raise( InvalidQuadFace, 'Invalid QuadFace' )
      end
      @faces = [ face ]
      @faces << face2 if face2.is_a?( Sketchup::Face )
    end
    
    # @return [Float]
    # @since 0.4.0
    def area
      total_area = 0.0
      @faces.each { |face| total_area += face.area }
      total_area
    end
    
    # @return [Sketchup::Material]
    # @since 0.3.0
    def back_material
      @faces[0].back_material
    end
    
    # @param [Sketchup::Material] new_material
    #
    # @return [Sketchup::Material]
    # @since 0.3.0
    def back_material=( new_material )
      for face in @faces
        face.back_material = new_material
      end
      face.back_material
    end
    
    # @param [QuadFace] quadface
    #
    # @return [Sketchup::Edge,Nil]
    # @since 0.1.0
    def common_edge( quadface )
      unless quadface.is_a?( QuadFace )
        raise( InvalidQuadFace, 'Invalid QuadFace' )
      end
      other_edges = quadface.edges
      match = edges.select { |edge| other_edges.include?( edge ) }
      return nil unless match
      match[0]
    end
    
    # Finds the quads connected to the quad's edges.
    #
    # @param [Array<Sketchup::Entity>] contraints
    #
    # @return [Array<QuadFace>]
    # @since 0.5.0
    def connected_quads( contraints = nil )
      connected = []
      for edge in edges
        for face in edge.faces
          next if faces.include?( face )
          next unless QuadFace.is?( face )
          quad = QuadFace.new( face )
          if contraints
            if quad.faces.all? { |f| contraints.include?( f ) }
              connected << quad
            end
          else
            connected << quad
          end
        end
      end
      connected
    end
    
    # @return [Boolean]
    # @since 0.1.0
    def detriangulate!
      if @faces.size == 2 && planar?
        # Materials
        material_front = material()
        material_back = back_material()
        texture_on_front = material_front && material_front.texture
        texture_on_back  = material_back  && material_back.texture
        if texture_on_front || texture_on_back
          uv_front = uv_get()
          uv_back = uv_get( false )
        end
        # Erase divider
        divider().erase!
        @faces = @faces.select { |face| face.valid? }
        # Restore materials
        uv_set( material_front, uv_front ) if texture_on_front
        uv_set( material_front, uv_back, false ) if texture_on_back
        true
      else
        false
      end
    end
    
    # @return [Sketchup::Edge,Nil]
    # @since 0.3.0
    def divider
      if @faces.size == 1
        nil
      else
        face1, face2 = @faces
        ( face1.edges & face2.edges )[0]
      end
    end
    
    # @param [Sketchup::Edge]
    #
    # @return [Boolean]
    # @since 0.1.0
    def edge_reversed?( edge )
      for face in @faces
        next unless face.edges.include?( edge )
        return edge.reversed_in?( face )
      end
    end
    
    # Returns the edge positions in the same order as the outer loop of the quad.
    #
    # @param [Sketchup::Edge] edge
    #
    # @return [Array<Geom::Point3d>]
    # @since 0.3.0
    def edge_positions( edge )
      edge_vertices( edge ).map { |vertex| vertex.position }
    end
    
    # Returns the edge vertices in the same order as the outer loop of the quad.
    #
    # @param [Sketchup::Edge] edge
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 0.3.0
    def edge_vertices( edge )
      if edge_reversed?( edge )
        edge.vertices.reverse
      else
        edge.vertices
      end
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.1.0
    def edges
      result = []
      if @faces.size == 1
        result = @faces[0].edges
      else
        for face in @faces
          result.concat( face.edges.select { |e| !QuadFace.divider_props?( e ) } )
        end
      end
      result
    end
    
    # @since 0.3.0
    def erase!
      if triangulated?
        edge = ( @faces[0].edges & @faces[1].edges )[0]
        edge.erase!
      else
        @faces[0].erase!
      end
    end
    
    # @return [Array<Sketchup::Face>]
    # @since 0.1.0
    def faces
      @faces.dup
    end
    
    # @return [Boolean]
    # @since 0.3.0
    def flip_edge
      if triangulated?
        verts = vertices()
        pts = verts.map { |v| v.position }
        div = divider()
        f1, f2 = @faces
        edges1 = f1.edges - [ div ]
        edges2 = f2.edges - [ div ]
        e1, e2 = edges1
        e3, e4 = edges2
        v1 = TT::Edges.common_vertex( e1, e2 )
        v2 = TT::Edges.common_vertex( e3, e4 )
        i1 = verts.index( v1 )
        # Materials
        material_front = material()
        material_back = back_material()
        texture_on_front = material_front && material_front.texture
        texture_on_back  = material_back  && material_back.texture
        if texture_on_front || texture_on_back
          uv_front = uv_get()
          uv_back = uv_get( false )
        end
        # Reorder points
        p1 = i1 
        p2 = ( p1 + 1 ) % 4
        p3 = ( p2 + 1 ) % 4
        p4 = ( p3 + 1 ) % 4
        pt1 = pts[ p1 ]
        pt2 = pts[ p2 ]
        pt3 = pts[ p3 ]
        pt4 = pts[ p4 ]
        # Recreate quadface
        entities = div.parent.entities
        div.erase!
        face1 = entities.add_face( pt1, pt2, pt3 )
        face2 = entities.add_face( pt1, pt4, pt3 )
        @faces = [ face1, face2 ]
        div = ( face1.edges & face2.edges )[0]
        div.soft = true
        div.smooth = true
        div.hidden = true
        # Restore materials
        if texture_on_front
          uv_set( material_front, uv_front )
        else
          material = material_front
        end
        if texture_on_back
          uv_set( material_front, uv_back, false )
        else
          back_material = material_back
        end
        true
      else
        false
      end
    end
    
    # @param [Sketchup::Face] face
    #
    # @return [Boolean]
    # @since 0.1.0
    def include?( face )
      @faces.include?( face )
    end
    
    # @return [Sketchup::Material]
    # @since 0.3.0
    def material
      @faces[0].material
    end
    
    # @param [Sketchup::Material] new_material
    #
    # @return [Sketchup::Material]
    # @since 0.1.0
    def material=( new_material )
      for face in @faces
        face.material = new_material
      end
      face.material
    end
    
    # @return [String]
    # @since 0.1.0
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
    
    # @return [Sketchup::Model]
    # @since 0.6.0
    def model
      @faces[0].model
    end
    
    # @return [Sketchup::Edge,nil]
    # @since 0.5.0
    def next_edge( edge )
      loop = outer_loop()
      index = loop.index( edge )
      return nil unless index
      next_index = ( index + 1 ) % 4
      loop[ next_index ]
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
    alias :next_quad :next_face
    
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
      if @faces.size == 1
        @faces[0].outer_loop.edges
      else
        sorted = TT::Edges.sort( edges ).uniq # .uniq due to a bug in TT_Lib 2.5
        # Ensure the edges run in the same direction as native outer loops.
        face = ( @faces & sorted[0].faces )[0]
        sorted.reverse! if sorted[0].reversed_in?( face )
        sorted
      end
    end
    
    # @return [Sketchup::Entities]
    # @since 0.6.0
    def parent
      @faces[0].parent
    end
    
    # @return [Boolean]
    # @since 0.2.0
    def planar?
      if @faces.size == 1
        true
      else
        TT::Geom3d.planar_points?( vertices() )
      end
    end
    
    # @return [Array<Geom::Point3d>]
    # @since 0.4.0
    def positions
      vertices.map { |vertex| vertex.position }
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
        # Materials
        material_front = material()
        material_back = back_material()
        texture_on_front = material_front && material_front.texture
        texture_on_back  = material_back  && material_back.texture
        if texture_on_front || texture_on_back
          uv_front = uv_get()
          uv_back = uv_get( false )
        end
        # (?) Validation required?
        face = @faces[0]
        entities = face.parent.entities
        mesh = face.mesh
        # Ensure a triangulated quad's edges doesn't have the properties of a
        # divider. If any of them has, then uncheck the hidden property.
        face.edges.each { |edge|
          if edge.soft? && edge.smooth? && edge.hidden?
            edge.hidden = false
          end
        }
        # Find the splitting segment.
        polygon1 = mesh.polygon_at( 1 ).map{ |i| i.abs }
        polygon2 = mesh.polygon_at( 2 ).map{ |i| i.abs }
        split = polygon1 & polygon2
        # Add edge at split
        split.map! { |index| mesh.point_at( index ) }
        edge = entities.add_line( *split )
        edge.soft = true
        edge.smooth = true
        edge.hidden = true
        # Update references
        @faces = edge.faces
        # Restore materials
        uv_set( material_front, uv_front ) if texture_on_front
        uv_set( material_front, uv_back, false ) if texture_on_back
        true
      else
        false
      end
    end
    
    # @since 0.4.0
    def uv_get( front = true )
      tw = Sketchup.create_texture_writer
      mapping = {}
      for face in @faces
        uvh = face.get_UVHelper
        for vertex in face.vertices
          next if mapping[ vertex ]
          if front
            uvq = uvh.get_front_UVQ( vertex.position )
          else
            uvq = uvh.get_back_UVQ( vertex.position )
          end
          mapping[ vertex ] = TT::UVQ.normalize( uvq )
        end
      end
      mapping
    end
    
    # @since 0.4.0
    def uv_set( new_material, mapping, front = true )
      unless new_material && new_material.texture
        material = new_material
        return false
      end
      for face in @faces
        uvs = []
        for vertex in face.vertices
          uvs << vertex.position
          uvs << mapping[ vertex ]
        end
        face.position_material( new_material, uvs, front )
      end
      true
    end
    
    # @return [Boolean]
    # @since 0.2.0
    def valid?
      if @faces.size == 1
        face = @faces[0]
        face.valid? &&
        face.vertices.size == 4 &&
        edges.all? { |e| !QuadFace.divider_props?( e ) }
      else
        @faces.size == 2 &&
        @faces.all? { |face|
          face.valid? &&
          face.vertices.size == 3
        } &&
        ( edge = @faces[0].edges & @faces[1].edges ).size == 1 &&
        QuadFace.divider_props?( edge[0] ) &&
        edge[0].faces.size == 2 &&
        edges.all? { |e| !QuadFace.divider_props?( e ) }
      end
    end
    
    # @return [Array<Sketchup::Vertices>]
    # @since 0.1.0
    def vertices
      # .uniq because .sort_vertices return the first vertex twice when the eges
      # form a loop.
      TT::Edges.sort_vertices( outer_loop() ).uniq
    end
    
    private
    
    # @param [Sketchup::Face] face
    #
    # @return [Sketchup::Face]
    # @since 0.1.0
    def other_native_face( face )
      return nil unless face.vertices.size == 3
      edges = face.edges.select { |e| QuadFace.divider_props?( e ) }
      return nil unless edges.size == 1
      dividing_edge = edges[0]
      return nil unless dividing_edge.faces.size == 2
      dividing_edge.faces.find { |f| f != face }
    end
    
    # @param [Sketchup::Face] face
    #
    # @return [Boolean] for native quad
    # @return [Sketchup::Face,Nil,False] for triangualted quads
    # @since 0.1.0
    def valid_native_face?( face )
      return false unless face.is_a?( Sketchup::Face )
      vertex_count = face.vertices.size
      return false if vertex_count < 3
      return false if vertex_count > 4
      # Check for bordering soft edges. Triangulated QuadFaces should have one
      # soft edge - where it joins the other triangle.
      # Native quads should have none.
      if vertex_count == 3
        edges = face.edges.select { |e| QuadFace.divider_props?( e ) }
        return false unless edges.size == 1
        face2 = other_native_face( face )
      else
        true # Native Quad
      end
    end
  
  end # class Quadface
  
  
  # @since 0.1.0
  class VirtualQuadFace < QuadFace
  
    # @param [Sketchup::Face] face
    #
    # @since 0.1.0
    def initialize( triangle1, triangle2 )
      unless triangle1.is_a?( Sketchup::Face ) && triangle2.is_a?( Sketchup::Face )
        raise( InvalidQuadFace, 'Invalid faces.' )
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
  
  
  # Manages QuadFace entities in an collection of native SketchUp entities.
  #
  # The internal lookup table of Sketchup::Face => QuadFace is build progressivly
  # as the entities is accessed in order to maintain performance.
  #
  # In some usage scenarios one will want to use #analyse to pre-build the
  # internal lookup table. For instance, if many native faces that makes up
  # QuadFaces is added to the EntitiesProvider and one wants to get all quads
  # from the collection using #quads - #analyse is needed to be called first.
  #
  # #each on the other hand will convert the native faces to Quads as it traverses
  # the collection. When the collection is traversed the next time this conversion
  # is not needed - therefore it's worth reusing the EntitiesProvider if possible.
  #
  # @since 0.6.0
  class EntitiesProvider
    
    include Enumerable
    
    # @since 0.6.0
    attr_reader( :model, :parent )
    
    # @param [Enumerable] entities
    # @param [Sketchup::Entities] parent
    #
    # @since 0.6.0
    def initialize( entities = [], parent = nil )
      # Model and parent references
      @model = nil
      @parent = nil
      if parent.nil?
        if entities.empty?
          @parent = Sketchup.active_model
          @model = Sketchup.active_model
        else
          entity = entities[0]
          @parent = entity.parent
          @model = entity.model
        end
      else
        @parent = parent
        @model = parent.model
      end
      # To quickly access entities by class this Hash is used.
      @types = {} # Class => Sketchup::Entity,QuadFace
      # Map native faces to QuadFace.
      @faces_to_quads = {} # Sketchup::Face => QuadFace
      # For quick access and lookup, store everything in a Hash table.
      for entity in entities
        cache_entity( entity )
      end
    end
    
    # Define proxy object that pass the call through to the parent
    # Sketchup::Entities object.
    [
      :add_3d_text,
      :add_arc,
      :add_circle,
      :add_cline,
      :add_cpoint,
      :add_curve,
      :add_edges,
      :add_face,
      :add_faces_from_mesh,
      :add_group,
      :add_image,
      :add_instance,
      :add_line,
      :add_ngon,
      :add_text,
      :clear!,
      :erase_entities,
      :fill_from_mesh,
      :intersect_with,
      :transform_by_vectors,
      :transform_entities
    ].each { |method|
      define_method( method ) { |*args| parent.send( method, *args ) }
    }
  
    # Returns the entity from the EntitiesProvider. Any Sketchup::Face
    # entity that makes up a QuadFace will be returned as a QuadFace class.
    #
    # If the QuadFace exists in the EntitiesProvider collection it will be
    # reused.
    #
    # Any faces that forms a QuadFace not in the collection will return as
    # a QuadFace, but will *not* be added to the collection.
    #
    # This differs from #get which will add new QuadFace entities to the
    # collection.
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Sketchup::Entity,QuadFace]
    # @since 0.6.0
    def []( entity )
      if quad = @faces_to_quads[ entity ]
        quad
      elsif QuadFace.is?( entity )
        quad = QuadFace.new( entity )
        cache_entity( quad ) if @types[ Sketchup::Face ][ entity ]
        quad
      else
        entity
      end
    end
    
    # @overload add( entity )
    #   @param [Sketchup::Entity,QuadFace] entity
    # @overload add( entity1, entity2, ... )
    #   @param [Sketchup::Entity,QuadFace] entity1
    #   @param [Sketchup::Entity,QuadFace] entity2
    # @overload add( enumerable )
    #   @param [Enumerable] enumerable
    #
    # @since 0.6.0
    def add( *args )
      if args.length == 1 && args.is_a?( Enumerable )
        entities = args[0]
      else
        entities = args
      end
      for entity in entities
        # (?) Verify parent?
        if entity.is_a?( QuadFace )
          # Special processing for QuadFaces.
          # If the quad's faces has already been added to the EntitiesProvider
          # then the already stored instance will be used.
          #
          # (?) Detect if any quads with two triangles share faces with another
          #     in case of invalid quads?
          if entity.faces.all? { |f| @faces_to_quads[ f ] }
            quad = @faces_to_quads[ entity.faces[0] ]
            cache_entity( quad )
          else
            cache_entity( entity )
          end
        else
          cache_entity( entity )
        end
      end # for
    end
    alias :<< :add
    
    # Add a QuadFace to the parent Sketchup::Entities collection.
    #
    # @overload add_quad( points )
    #   @param [Array<Geom::Point3d>] points
    # @overload add_quad( point1, point2, point3, point4 )
    #   @param [Geom::Point3d] point1
    #   @param [Geom::Point3d] point2
    #   @param [Geom::Point3d] point3
    #   @param [Geom::Point3d] point4
    # @overload add_quad( edges )
    #   @param [Array<Sketchup::Edge>] edges
    # @overload add_quad( edge1, edge2, edge3, edge4 )
    #   @param [Sketchup::Edge] edge1
    #   @param [Sketchup::Edge] edge2
    #   @param [Sketchup::Edge] edge3
    #   @param [Sketchup::Edge] edge4
    # @overload add_quad( curve )
    #   @param [Sketchup::Curve] curve
    #
    # @since 0.6.0
    def add_quad( *args )
      # (!)
    end
    
    # @since 0.6.0
    def all
      @types.values.map { |hash| hash.keys }.flatten
    end
    alias :to_a :all
    
    # Processes the given set of entities give to #new and builds the cache
    # with native entities and QuadFace entities.
    #
    # @since 0.6.0
    def analyse
      for entity in all
        if @faces_to_quads[ entity ].nil? && QuadFace.is?( entity )
          quad = QuadFace.new( entity )
          cache_entity( quad )
        else
          cache_entity( entity )
        end
      end
      nil
    end
    
    # Traverses the given set of entities given to #new. Discovers and cache
    # QuadFaces on the fly.
    #
    # @since 0.6.0
    def each
      # Cache to ensure unprocessed quad's native faces doesn't return twice.
      skip = {}
      for entity in all
        if entity.is_a?( Sketchup::Face )
          next if skip[ entity ]
          if quad = @faces_to_quads[ entity ]
            # Existing Quad
            for face in quad.faces
              skip[ face ] = face
            end
            yield( quad )
          elsif QuadFace.is?( entity )
            # Unprocessed Quad
            quad = QuadFace.new( entity )
            cache_entity( quad )
            for face in quad.faces
              skip[ face ] = face
            end
            yield( quad )
          else
            # Native Face
            cache_entity( entity )
            yield( entity )
          end
        else
          # All other entities
          cache_entity( entity )
          yield( entity )
        end
      end
    end
    
    # Returns all the edges for the cached entities.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @return [Array<Sketchup::Edge>]
    # @since 0.6.0
    def edges
      @types[ Sketchup::Edge ].keys
    end
    
    # @return [Boolean]
    # @since 0.6.0
    def empty?
      all.empty?
    end
    
    # Returns all cached faces and QuadFaces.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @return [Array<Sketchup::Face,QuadFace>]
    # @since 0.6.0
    def faces
      @types[ QuadFace ].keys + @types[ Sketchup::Face ].keys
    end
    
    # Returns the entity from the EntitiesProvider. Any Sketchup::Face
    # entity that makes up a QuadFace will be returned as a QuadFace class.
    #
    # If the QuadFace exists in the EntitiesProvider collection it will be
    # reused.
    #
    # Any faces that forms a QuadFace not in the collection will return as
    # a QuadFace and added to the collection.
    #
    # This differs from #[] which will not add new QuadFace entities to the
    # collection.
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Sketchup::Entity,QuadFace]
    # @since 0.6.0
    def get( entity )
      if quad = @faces_to_quads[ entity ]
        quad
      elsif QuadFace.is?( entity )
        quad = QuadFace.new( entity )
        cache_entity( quad )
        quad
      else
        entity
      end
    end
    
    # Returns an array of all cached entities of the given class.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @param [Class] klass
    #
    # @return [Array<Sketchup::Entity,QuadFace>]
    # @since 0.6.0
    def get_by_type( klass )
      @types[ klass ].keys
    end
    
    # @return [String]
    # @since 0.6.0
    def include?( entity )
      if entities = @types[ entity.class ]
        entities.include?( entity ) ||
        @faces_to_quads.include?( entity )
      else
        @faces_to_quads.include?( entity )
      end
    end
    
    # @return [String]
    # @since 0.6.0
    def inspect
      hex_id = TT.object_id_hex( self )
      "#<#{self.class.name}:#{hex_id}>"
    end
    
    # @return [Integer]
    # @since 0.6.0
    def length
      all.length
    end
    alias :size :length
    
    # Returns all cached native entities.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @return [Array<Sketchup::Face>]
    # @since 0.6.0
    def native_entities
      entities = []
      for type, type_entities in @types
        if type == QuadFace
          entities.concat( type_entities.map { |quad| quad.faces } )
        else
          entities.concat( type_entities )
        end
      end
      entities
    end
    
    # Returns all native faces for the cached entities.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @return [Array<Sketchup::Face>]
    # @since 0.6.0
    def native_faces
      @faces_to_quads.keys + @types[ Sketchup::Face ].keys
    end
    
    # Returns all cached QuadFaces.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @return [Array<QuadFace>]
    # @since 0.6.0
    def quads
      @types[ QuadFace ].keys
    end
    
    # Returns all the native faces for the cached QuadFaces.
    #
    # Use #analyse prior to this when full set if required.
    #
    # @return [Array<QuadFace>]
    # @since 0.6.0
    def quad_faces
      @faces_to_quads.keys
    end
    
    private
    
    # @param [Sketchup::Entity] entity
    #
    # @return [Sketchup::Entity]
    # @since 0.6.0
    def cache_entity( entity )
      entity_class = entity.class
      # Add to Type cache
      @types[ entity_class ] ||= {}
      @types[ entity_class ][ entity ] = entity
      # Add to Face => QuadFace mapping
      if entity.is_a?( QuadFace )
        for face in entity.faces
          @faces_to_quads[ face ] = entity
          @types[ Sketchup::Face ].delete( face )
        end
      end
      entity
    end
    
  end # class EntitiesProvider
  
end # module