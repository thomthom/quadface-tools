#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools

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
        return false unless other_face.vertices.size == 3
        soft_edges = other_face.edges.select { |e| e.soft? }
        return false unless soft_edges.size == 1
      else # face.vertices.size == 4
        # Pure Quadface
        #return false if soft_edges.size > 0
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
      return false unless edge.faces.size == 2
      return false unless edge.faces.all? { |face| face.vertices.size == 3 }
      return false unless edge.soft?
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
      if @faces.size == 1
        result = @faces[0].edges
      else
        for face in @faces
          result.concat( face.edges.select { |e| !e.soft? } )
        end
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
    
    # @return [Array<Sketchup::Vertices>]
    # @since 0.1.0
    def vertices
      outer_loop.map { |edge| edge.vertices }.flatten.uniq
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
        #soft_edges = face.edges.select { |e| e.soft? }
        #return false if soft_edges.size > 0
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
  
end # module