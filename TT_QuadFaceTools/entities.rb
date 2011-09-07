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
    
    # Evaluates if the entity is a face that forms part of a QuadFace.
    #
    # @see {QuadFace}
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.is?( face )
      return false unless face.valid?
      return false unless face.is_a?( Sketchup::Face )
      vertex_count = face.vertices.size
      return false if vertex_count < 3
      return false if vertex_count > 4
      # Triangulated QuadFace needs special treatment.
      if vertex_count == 3
        soft_edges = face.edges.select { |e| e.soft? }
        return false unless soft_edges.size == 1
        dividing_edge = soft_edges[0]
        return false unless dividing_edge.faces.size == 2
        other_face = ( dividing_edge.faces - [face] ).first
        return false unless other_face.vertices.size == 3
        soft_edges = other_face.edges.select { |e| e.soft? }
        return false unless soft_edges.size == 1
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
    def self.dividing_edge?( edge )
      return false unless edge.is_a?( Sketchup::Edge )
      return false unless edge.soft?
      return false unless edge.faces.size == 2
      return false unless edge.faces.all? { |face| face.vertices.size == 3 }
      edge.faces.all? { |face| self.is?( face ) }
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
    
    # @param [Sketchup::Face] face
    #
    # @since 0.1.0
    def initialize( face )
      # (!) The creating of a QuadFace is slow. Improve.
      unless face2 = valid_native_face?( face )
        raise( InvalidQuadFace, 'Invalid QuadFace' )
      end
      @faces = [ face ]
      @faces << face2 if face2.is_a?( Sketchup::Face )
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
          result.concat( face.edges.select { |e| !e.soft? } )
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
    
    # @return [Boolean]
    # @since 0.2.0
    def planar?
      if @faces.size == 1
        true
      else
        TT::Geom3d.planar_points?( vertices() )
      end
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
        # Ensure a triangulated quad's edges isn't soft.
        face.edges.each { |edge|
          if edge.soft?
            edge.soft = false
            edge.hidden = true
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
        # Update references
        @faces = edge.faces
        true
      else
        false
      end
    end
    
    # @return [Boolean]
    # @since 0.1.0
    def detriangulate!
      if @faces.size == 2 && planar?
        edge = ( @faces[0].edges & @faces[1].edges )[0]
        edge.erase!
        @faces = @faces.select { |face| face.valid? }
      else
        true
      end
    end
    
    # @return [Array<Sketchup::Vertices>]
    # @since 0.1.0
    def vertices
      # .uniq because .sort_vertices return the first vertex twice when the eges
      # form a loop.
      TT::Edges.sort_vertices( outer_loop() ).uniq
    end
    
    # @return [Boolean]
    # @since 0.2.0
    def valid?
      if @faces.size == 1
        face = @faces[0]
        face.valid? &&
        face.vertices.size == 4
      else
        @faces.size == 2 &&
        @faces.all? { |face|
          face.valid? &&
          face.vertices.size == 3
        } &&
        ( edge = @faces[0].edges & @faces[1].edges ).size == 1 &&
        edge[0].soft? &&
        edge[0].faces.size == 2 &&
        edges.all? { |e| !e.soft? }
      end
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
      #( dividing_edge.faces - [face] ).first
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
        soft_edges = face.edges.select { |e| e.soft? }
        return false unless soft_edges.size == 1
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
  
  
  # @since 0.2.0
  class EntitiesProvider
    
    include Enumerable
    
    # @since 0.2.0
    attr_reader( :model, :parent )
    
    # @param [Enumerable] entities
    #
    # @since 0.2.0
    def initialize( entities )
      # Model references
      @model = nil
      @parent = nil
      unless entities.length == 0
        entity = entities[0]
        @parent = entity.parent
        @model = entity.model
      end
      # Entities
      @entities = entities.to_a
      @faces_to_quads = {}
      @faces_and_quads = []
      @faces = [] # All native faces in collection, including Quad's faces.
      @quads = [] # All QuadFaces in collection
      @edges = []
      for entity in entities
        if entity.is_a?( Sketchup::Edge )
          @edges << entity
        elsif entity.is_a?( Sketchup::Face )
          unless @faces_to_quads[ entity ]
            if QuadFace.is?( entity )
              quad = QuadFace.new( entity )
              @faces << quad.faces[0]
              @faces << quad.faces[1]
              @faces_and_quads << quad
              @faces_to_quads[ quad.faces[0] ] = quad
              @faces_to_quads[ quad.faces[1] ] = quad
            else
              @faces << entity
              @faces_and_quads << entity
            end
          end
        end
      end
    end
    
    # @since 0.2.0
    def each( &block )
      @entities.each( &block )
    end
    
    # @return [Array<Sketchup::Face,QuadFace>]
    # @since 0.2.0
    def faces
      @faces_and_quads.to_a
    end
    
    # @return [Array<QuadFace>]
    # @since 0.2.0
    def quads
      @quads.to_a
    end
    
    # @return [Array<QuadFace>]
    # @since 0.2.0
    def quad_faces
      @faces_to_quads.keys
    end
    
    # @return [Array<Sketchup::Face>]
    # @since 0.2.0
    def native_faces
      @faces.to_a
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.2.0
    def edges
      @edges.to_a
    end
    
    # @return [QuadFace,Sketchup::Face]
    # @since 0.2.0
    def get_face( face )
      @faces_to_quads[ face ] || face
    end
    
    # @return [Array<Sketchup::Entity,QuadFace>]
    # @since 0.2.0
    def to_a
      @entities.to_a
    end
    
    # @return [Integer]
    # @since 0.2.0
    def length
      @entities.length
    end
    alias :size :length
    
    # @return [Boolean]
    # @since 0.2.0
    def empty?
      @entities.empty?
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      hex_id = TT.object_id_hex( self )
      "#<#{self.class.name}:#{hex_id}>"
    end
    
  end # class EntitiesProvider
  
end # module