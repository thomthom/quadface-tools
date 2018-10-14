#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'set'

require 'TT_QuadFaceTools/algorithms'
require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/geometry'

module TT::Plugins::QuadFaceTools
  # Class representing a triangulated quad. This differs from QuadFace in that
  # it will take two faces and an edge and treat them as a quad unit. This means
  # it can operate on Sandbox Tools' quads.
  #
  # It would be nice to merge this into QuadFace eventually. Though this require
  # some refactoring.
  class QuadSlope

    include Algorithms

    # @!attribute [r] edges
    #   @return [Array<Sketchup::Edge>]

    # @!attribute [r] faces
    #   @return [Array<Sketchup::Face>]

    attr_reader :faces, :edge

    # @param [Sketchup::Face] face1
    #
    # @return [QuadSlope]
    def self.find(face1)
      # TODO: Try to pick real Quad first.
      return nil unless face1 && face1.edges.size == 3
      edges = face1.edges.select { |edge| edge.soft? || edge.hidden? }
      return nil unless edges.size == 1
      edge = edges.first
      return nil unless edge.faces.size == 2
      face2 = (edge.faces - [face1]).first
      self.new(face1, face2, edge)
    end

    # @param [Sketchup::Face] face1
    # @param [Sketchup::Face] face2
    # @param [Sketchup::Edge] edge
    def initialize(face1, face2, edge = nil)
      @faces = [face1, face2].sort { |a, b| a.entityID <=> b.entityID }
      @edge = edge || (face1.edges & face2.edges).first
      @edge = edge
    end

    def valid?
      @edge.valid? && @faces.all? { |face| face.valid? }
    end

    # @return [Boolean]
    def orient_by_slope
      flip unless smooth_slope?
    end

    # @return [Boolean]
    def flip
      # KLUDGE: This uses the flip logic of QuadFace, which means the edge
      #   need to have the expected properties. Because of that the edge's
      #   properties are cached.
      properties = [@edge.soft?, @edge.smooth?, @edge.hidden?, @edge.layer, @edge.material]
      QuadFace.set_divider_props(@edge)
      # Now the flip can be performed.
      quad = QuadFace.new(*@faces)
      result = quad.flip_edge
      # Ensure the properties are restored.
      soft, smooth, hidden, layer, material = properties
      diagonal = quad.divider
      diagonal.soft = soft
      diagonal.smooth = smooth
      diagonal.visible = !hidden
      diagonal.layer = layer
      diagonal.material = material

      result
    end

    # @note The returned vertices are *not* sorted in loop order.
    #
    # @return [Array<Sketchup::Vertex>]
    def vertices
      f1, f2 = @faces
      f1.outer_loop.vertices << (f2.vertices - f1.vertices).first
    end

    # @note The returned edges are sorted in loop order.
    #
    # @return [Array<Sketchup::Edge>]
    def edges
      unsorted_edges = @faces.map(&:edges).flatten.uniq - [@edge]
      TT::Edges.sort(unsorted_edges)
    end

    # @return [Array<Geom::Point3d>]
    def positions
      vertices.map(&:position)
    end

    # The average position of all the vertices.
    #
    # @return [Geom::Point3d]
    def centroid
      TT::Geom3d.average_point(positions)
    end

    # The mid-point of the diagonal edge between the quad's two triangles.
    #
    # @return [Geom::Point3d]
    def diagonal_center
      pt1, pt2 = edge.vertices.map(&:position)
      Geom.linear_combination(0.5, pt1, 0.5, pt2)
    end

    # The normal for the best fit plane of the quad.
    #
    # @return [Geom::Vector3d]
    def normal
      # Geom.fit_plane_to_points might return a plane which faces the opposite
      # direction of the average normal of the quad. So instead the vertices
      # are projected to the average plane and a normal generated from that.
      quad_plane = plane
      points = @faces.first.outer_loop.vertices.map { |vertex|
        vertex.position.project_to_plane(quad_plane)
      }
      Geometry.triangle_normal(*points)
    end

    # Best fit plane of the quad's vertices.
    #
    # @return [Array(Float, Float, Float, Float)]
    def plane
      Geom.fit_plane_to_points(vertices)
    end

    def planar?
      TT::Geom3d.planar_points?(vertices)
    end

    # @param [Sketchup::Edge] edge
    #
    # @return [QuadSlope]
    def other_face(edge)
      other_faces = edge.faces - @faces
      return nil unless other_faces.size == 1
      other_face = other_faces.first
      self.class.find(other_face) #| other_face # TODO: Support native faces
    end

    # @return [Array<QuadSlope>] Orthogonal neighbouring quads
    def neighbours
      processed = Set.new(@faces)
      quads = []
      edges.each { |edge|
        edge.faces.each { |face|
          next if processed.include?(face)
          processed.add(face)
          quad = self.class.find(face)
          next if quad.nil?
          processed.merge(quad.faces)
          quads << quad
        }
      }
      quads
    end

    def smooth_slope?
      return true if planar?
      return true if neighbours.empty?
      # First two edges much match the one of the existing triangles. This is
      # because this method evaluates whether the current configuration of
      # triangles is the "smoothest".
      edges1 = edges
      vertex = TT::Edges.common_vertex(*edges1.first(2))
      edges1 = rotate(edges1) if @edge.vertices.include?(vertex)
      # Second set is rotated by one, representing flipped triangles.
      edges2 = rotate(edges1)
      # Compare the deviances of the two possible triangle orientations.
      # If `average1` is smallest it means the current triangle orientation
      # is the one that best matches the surface curvature of it's neighbours.
      average1 = average_deviance_from_slope(edges1)
      average2 = average_deviance_from_slope(edges2)
      average1 <= average2
    end

    private

    # @param [Array<Sketchup::Edge>] edge_set Set of four edges
    #
    # @return [Float]
    def average_deviance_from_slope(edge_set)
      return 0.0 if edge_set.empty?
      raise "Expected 4 edges, got #{edge_set.size}" unless edge_set.size == 4
      # Check each of the triangles and see how much their normals deviate from
      # the average normal of the local surface.
      deviances = edge_set.each_slice(2).map { |slice|
        # Two edges (sorted) represent a triangle.
        raise "Expected 2 edges, got #{slice.size}" unless slice.size == 2
        # Compute the average normal of this quad and the connected quads for
        # the triangle we're currently working with.
        other_faces = slice.map { |edge| other_face(edge) }.compact << self
        vectors = other_faces.map(&:normal)
        average_vector = Geometry.average_vector(vectors)
        next 0.0 unless average_vector.valid?
        # Compute the normal of the current triangle.
        vertices = slice.map(&:vertices).flatten.uniq
        points = vertices.map(&:position)
        raise "Expected 3 points, got #{points.size}" unless points.size == 3
        triangle_normal = Geometry.triangle_normal(*points)
        # Must ensure triangle normal is in the same direction as the quad's
        # normal.
        triangle_normal.reverse! if triangle_normal % normal < 0.0
        triangle_normal.angle_between(average_vector)
      }
      sum(deviances) / 2.0
    end

  end # class
end # module
