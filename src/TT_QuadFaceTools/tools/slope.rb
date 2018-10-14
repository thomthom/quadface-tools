#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'set'

module TT::Plugins::QuadFaceTools

  class SlopeInspectTool

    class QuadSlope

      attr_reader :faces, :edge

      def initialize(face1, face2, edge = nil)
        @faces = [face1, face2].sort { |a, b| a.entityID <=> b.entityID }
        @edge = edge || (face1.edges & face2.edges).first
        @edge = edge
      end

      def valid?
        @edge.valid? && @faces.all? { |face| face.valid? }
      end

      def orient_by_slope
        flip unless smooth_slope?
      end

      def flip
        properties = [@edge.soft?, @edge.smooth?, @edge.hidden?, @edge.layer, @edge.material]
        QuadFace.set_divider_props(@edge)

        quad = QuadFace.new(*@faces)
        result = quad.flip_edge

        soft, smooth, hidden, layer, material = properties
        diagonal = quad.divider
        diagonal.soft = soft
        diagonal.smooth = smooth
        diagonal.visible = !hidden
        diagonal.layer = layer
        diagonal.material = material

        result
      end

      def vertices
        f1, f2 = @faces
        f1.outer_loop.vertices << (f2.vertices - f1.vertices).first
      end

      def edges
        unsorted_edges = @faces.map(&:edges).flatten.uniq - [@edge]
        TT::Edges.sort(unsorted_edges)
      end

      def positions
        vertices.map(&:position)
      end

      def centroid
        TT::Geom3d.average_point(positions)
      end

      def diagonal_center
        pt1, pt2 = edge.vertices.map(&:position)
        Geom.linear_combination(0.5, pt1, 0.5, pt2)
      end

      def normal
        # Geom.fit_plane_to_points might return a plane which faces the opposite
        # direction of the average normal of the quad. So instead the vertices
        # are projected to the average plane and a normal generated from that.
        quad_plane = plane
        points = @faces.first.outer_loop.vertices.map { |v|
          v.position.project_to_plane(quad_plane)
        }
        pt1, pt2, pt3 = points
        vx = pt1.vector_to(pt2)
        vy = pt1.vector_to(pt3)
        (vx * vy).normalize
      end

      def plane
        Geom.fit_plane_to_points(vertices)
      end

      def planar?
        TT::Geom3d.planar_points?(vertices)
      end

      def other_face(edge)
        other_faces = edge.faces - @faces
        return nil unless other_faces.size == 1
        other_face = other_faces.first
        QuadSlope.find(other_face) #| other_face # TODO: Support native faces
      end

      def average_deviance(edge_set, debug = false)
        return 0.0 if edge_set.empty?
        raise "Expected < 4 edges, got #{edge_set.size}" if edge_set.size > 4

        deviances = edge_set.each_slice(2).map { |slice|
          raise "Expected 2 edges, got #{slice.size}" unless slice.size == 2
          other_faces = slice.map { |edge| other_face(edge) }.compact << self
          vectors = other_faces.map(&:normal)
          average_vector = average_vector(vectors)
          next 0.0 unless average_vector.valid?

          vertices = slice.map(&:vertices).flatten.uniq
          points = vertices.map(&:position)
          raise "Expected 3 points, got #{points.size}" unless points.size == 3
          triangle_normal = points_normal(*points)
          # Must ensure triangle normal is in the same direction as the quad's
          # normal.
          triangle_normal.reverse! if triangle_normal % normal < 0.0
          triangle_normal.angle_between(average_vector)
        }
        sum(deviances) / 2.0
      end

      def smooth_slope?(debug = false)
        return true if planar?
        return true if neighbours.empty?

        # First two edges much match one of the existing triangles.
        edges1 = edges
        vertex = TT::Edges.common_vertex(*edges1.first(2))
        edges1 = rotate(edges1) if @edge.vertices.include?(vertex)

        # Second set is rotated by one, representing flipped triangles.
        edges2 = rotate(edges1)

        raise "Expected 4 edges, got #{edges1.size}" unless edges1.size == 4
        raise "Expected 4 edges, got #{edges2.size}" unless edges2.size == 4

        average1 = average_deviance(edges1, debug)
        average2 = average_deviance(edges2, debug)

        average1 <= average2
      end

      # TODO: Move to Geometry
      def average_vector(vectors)
        vectors.inject(Geom::Vector3d.new) { |s, v| s + v }.normalize
      end

      # TODO: Move to Geometry
      def points_normal(pt1, pt2, pt3)
        x_axis = pt1.vector_to(pt2)
        y_axis = pt1.vector_to(pt3)
        (x_axis * y_axis).normalize
      end

      # TODO:Move to EnumerableHelper
      def sum(enumerable)
        enumerable.inject(0) { |sum, x| sum + x }
      end

      # TODO:Move to EnumerableHelper
      def rotate(enumerable, n = 1)
        enumerable.map.with_index { |x, i|
          i2 = (i + n) % enumerable.size
          enumerable[i2]
        }
      end

      def self.find(face1)
        # TODO: Try to pick real Quad first.
        return nil unless face1 && face1.edges.size == 3
        edges = face1.edges.select { |edge| edge.soft? || edge.hidden? }
        return nil unless edges.size == 1
        edge = edges.first
        return nil unless edge.faces.size == 2
        face2 = (edge.faces - [face1]).first
        QuadSlope.new(face1, face2, edge)
      end

      def neighbours
        processed = Set.new(@faces)
        quads = []
        edges.each { |edge|
          edge.faces.each { |face|
            next if processed.include?(face)
            processed.add(face)
            quad = QuadSlope.find(face)
            next if quad.nil?
            processed.merge(quad.faces)
            quads << quad
          }
        }
        quads
      end

    end # class


    def initialize
      @quad = nil
      @quads = []
    end

    def activate
      @quads = find_quads(Sketchup.active_model.active_entities)
      update_ui
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def deactivate(view)
      view.invalidate
    end

    def onCancel(reason, view)
      puts "onCancel(#{reason})"
      # reason == 2 : Undo
      @quads = []
      UI.start_timer(0.0, false) do
        @quads = find_quads(Sketchup.active_model.active_entities)
        view.invalidate
      end
    end

    def resume(view)
      update_ui
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onMouseMove(flags, x, y, view)
      @quad = pick_quad(x, y, view)
      view.invalidate
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onLButtonUp(flags, x, y, view)
      flip_quads(@quads)
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    TEXT_OPTIONS = {
      font: "Arial",
      size: 10,
      bold: true,
      color: 'white',
      align: TextAlignCenter,
    }

    # @param [Sketchup::View] view
    def draw(view)
      draw_quads(view)

      return unless @quad && @quad.valid?

      # Quad
      color = color = @quad.smooth_slope?(false) ? [0, 255, 0, 64] : [255, 0, 0, 64]
      draw_quad(view, @quad, color)
      n1, n2 = quad_normal_segment(view, @quad)

      @quad.neighbours.each { |neighbour|
        color = color = neighbour.smooth_slope? ? [0, 255, 0, 64] : [255, 0, 0, 64]
        draw_quad(view, neighbour, color)

        points = quad_normal_segment(view, neighbour)
        position = view.screen_coords(points.last)
        position.y -= TEXT_OPTIONS[:size] + 5
        angle = @quad.normal.angle_between(neighbour.normal)
        angle_formatted = Sketchup.format_angle(angle)
        sign = neighbour.normal % @quad.normal

        distance1 = points.first.distance(n1)
        distance2 = points.last.distance(n2)
        dir = '?'
        dir = if distance1 == distance2
          'same'
        else
          distance1 > distance2 ? 'toward' : 'away'
        end

        text = "#{angle_formatted}° (#{dir})" #+ "\n#{sign}"
        view.draw_text(position, text, TEXT_OPTIONS)
      }
    end

    private

    def draw_quad(view, quad, color)
      # Faces
      triangles = quad.faces.map { |face| face.vertices.map(&:position) }
      view.drawing_color = color
      view.draw(GL_TRIANGLES, triangles.flatten)
      # Diagonal
      view.line_stipple = '_'
      view.line_width = 2
      view.drawing_color = color
      view.draw(GL_LINES, quad.edge.vertices.map(&:position))
      # Edges
      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = 'purple'
      vertices = quad.edges.map { |edge| edge.vertices }.flatten
      # points = vertices.map(&:position)
      camera_normal = view.camera.direction.reverse
      points = vertices.map { |vertex|
        size = view.pixels_to_model(1, vertex.position) * 0.2
        vertex.position.offset(camera_normal, size)
      }
      view.draw(GL_LINES, points)
      # Normal
      normal_segment = quad_normal_segment(view, quad)
      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = 'orange'
      view.draw(GL_LINES, normal_segment)
    end

    def quad_normal_segment(view, quad)
      size = quad.edge.length / 2.0
      center = quad.diagonal_center
      [center, center.offset(quad.normal, size)]
    end

    def draw_quads(view)
      return if @quads.empty?
      groups = @quads.group_by { |quad| quad.smooth_slope? }
      groups.each { |smooth, quads|
        faces = quads.map(&:faces).flatten.uniq
        triangles = faces.map { |face| face.vertices.map(&:position) }
        view.drawing_color = smooth ? [0, 255, 0, 64] : [255, 0, 0, 64]
        view.draw(GL_TRIANGLES, triangles.flatten)

        normals = quads.map { |quad|
          size = quad.edge.length / 2.0
          center = quad.diagonal_center
          [center, center.offset(quad.normal, size)]
        }.flatten
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = 'orange'
        view.draw(GL_LINES, normals)
      }
    end

    def update_ui
      Sketchup.status_text = 'Click to reorient triangulation by slope.'
      nil
    end

    def flip_quads(quads)
      model = Sketchup.active_model
      model.start_operation('Orient to Slope', true)
      quads.each { |quad|
        quad.orient_by_slope
      }
      model.commit_operation
      # TODO: Update after commit.
      @quad = nil
      @quads = find_quads(Sketchup.active_model.active_entities)
      nil
    end

    def find_quads(entities)
      processed = Set.new
      quads = []
      entities.grep(Sketchup::Face) { |face|
        next if processed.include?(face)
        quad = create_quad_slope(face)
        next unless quad
        next if quad.planar?
        processed.merge(quad.faces)
        quads << quad
      }
      quads
    end

    def create_quad_slope(face1)
      # TODO: Try to pick real Quad first.
      return nil unless face1 && face1.edges.size == 3
      edges = face1.edges.select { |edge| edge.soft? || edge.hidden? }
      return nil unless edges.size == 1
      edge = edges.first
      return nil unless edge.faces.size == 2
      face2 = (edge.faces - [face1]).first
      QuadSlope.new(face1, face2, edge)
    end

    def pick_quad(x, y, view)
      # TODO: Try to pick real Quad first.
      ph = view.pick_helper(x, y, 5)
      create_quad_slope(ph.picked_face)
    end

  end # class

end # module
