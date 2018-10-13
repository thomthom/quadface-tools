#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'matrix'
require 'set'

module TT::Plugins::QuadFaceTools

  class SlopeInspectTool

    class Normal

      attr_reader :centroid, :vector, :points

      def self.from_face(face)
        positions = face.vertices.map(&:position)
        centroid = TT::Geom3d.average_point(positions)
        vector = face.normal
        self.new(centroid, vector)
      end

      def self.from_quad(quad)
        self.new(quad.centroid, quad.plane_normal2)
      end

      def initialize(centroid, vector)
        @centroid = Geom::Point3d.new(centroid)
        @vector = Geom::Vector3d.new(vector).normalize
        @points = normal_points(centroid, vector)
      end

      SLOPE_SAME = 0
      SLOPE_TOWARDS = -1
      SLOPE_AWAY = 1

      def slope_compare(normal)
        n1, n2 = normal.points

        distance1 = points.first.distance(n1)
        distance2 = points.last.distance(n2)

        if distance1 == distance2
          SLOPE_SAME
        else
          distance1 > distance2 ? SLOPE_TOWARDS : SLOPE_AWAY
        end
      end

      def slope_towards?(normal)
        slope_compare(normal) == SLOPE_TOWARDS
      end

      def slope_away?(normal)
        slope_compare(normal) == SLOPE_AWAY
      end

      def slope_same?(normal)
        slope_compare(normal) == SLOPE_SAME
      end

      private

      def normal_points(centroid, vector)
        # [centroid, centroid.offset(vector, 100)]
        [centroid, centroid.offset(vector)]
      end

    end

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
        # @faces.map(&:vertices).flatten.uniq
        f1, f2 = @faces
        f1.outer_loop.vertices << (f2.vertices - f1.vertices).first
      end

      def sort_edges(edges, loop)
        e1, e2 = *edges
        v1 = loop.vertices.first
        v2 = (e1.vertices & e2.vertices).first
        start_edge = v1.common_edge(v2)
        edges.index(start_edge) == 0 ? edges : edges.reverse
      end

      def edges
        e1 = sort_edges(@faces[0].outer_loop.edges - [@edge], @faces[0].outer_loop)
        e2 = sort_edges(@faces[1].outer_loop.edges - [@edge], @faces[1].outer_loop)
        # e1 + e2
        # e1 + e2.reverse
        TT::Edges.sort(e1 + e2)

        # x = @faces.map { |f| f.outer_loop.edges }.flatten.uniq
        # x.delete(@edge)
        # x
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
        f1, f2 = @faces
        Geom.linear_combination(0.5, f1.normal, 0.5, f2.normal)
      end

      def plane
        Geom.fit_plane_to_points(positions)
      end

      def plane_normal
        a, b, c, d = plane
        Geom::Vector3d.new(a, b, c).normalize
      end

      def plane_normal2
        quad_plane = plane
        points = @faces.first.outer_loop.vertices.map { |v|
          v.position.project_to_plane(quad_plane)
        }
        pt1, pt2, pt3 = points
        vx = pt1.vector_to(pt2)
        vy = pt1.vector_to(pt3)
        # vx * vy
        (vx * vy).normalize
      end

      def planar?
        TT::Geom3d.planar_points?(vertices)
      end

      Vertex = Struct.new(:entity, :position)

      def sum(enumerable)
        enumerable.inject(0) { |sum, x| sum + x }
      end

      def other_face(edge)
        other_faces = edge.faces - @faces
        return nil unless other_faces.size == 1
        other_face = other_faces.first
        QuadSlope.find(other_face) #| other_face
      end

      def towards?(face1, face2)
        face1_normal = face1.is_a?(QuadSlope) ? face1.plane_normal2 : face1.normal
        face2.vertices.map(&:position).any? { |point|
          plane_point = point.project_to_plane(face1.plane)
          vector = plane_point.vector_to(point)
          vector.valid? && vector.samedirection?(face1_normal)
        }
      end

      # https://stackoverflow.com/a/15691064/486990
      def towards_pts?(pts1, pts2)
        a, b, c, d = Geom.fit_plane_to_points(pts1)
        pts2.any? { |pt|
          x, y, z = *pt.to_a
          dot( [a,b,c,d], [x,y,z,1] ) > 0
        }
        # dot( (a,b,c,d), (x,y,z,1) ) > 0
      end

      def dot(n1, n2)
        Vector[*n1].inner_product Vector[*n2]
      end

      def average_vector(vectors)
        average = vectors.inject(Geom::Vector3d.new) { |s, v| s + v }
        # average.x /= vectors.size
        # average.y /= vectors.size
        # average.z /= vectors.size
        # average
        average.normalize
      end

      def rotate(enumerable, n = 1)
        enumerable.map.with_index { |x, i|
          i2 = (i + n) % enumerable.size
          enumerable[i2]
        }
      end

      def average_deviance(edge_set, debug = false)
        return 0.0 if edge_set.empty?
        raise "Expected < 4 edges, got #{edge_set.size}" if edge_set.size > 4

        puts if debug
        puts 'average_deviance' if debug
        deviances = edge_set.each_slice(2).map { |slice|
          raise "Expected 2 edges, got #{slice.size}" unless slice.size == 2
          other_faces = slice.map { |edge| other_face(edge) }.compact << self
          vectors = other_faces.map(&:plane_normal2)
          average_vector = average_vector(vectors)
          next 0.0 unless average_vector.valid?

          vertices = slice.map(&:vertices).flatten.uniq
          points = vertices.map(&:position)
          raise "Expected 3 points, got #{points.size}" unless points.size == 3
          triangle_normal = pts_normal(*points)
          # Must ensure triangle normal is in the same direction as the quad's
          # normal.
          triangle_normal.reverse! if triangle_normal % plane_normal2 < 0.0
          a = triangle_normal.angle_between(average_vector)
          p ['vectors', a.radians, triangle_normal, average_vector, vectors] if debug
          a
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

        puts if debug
        puts 'smooth_slope?' if debug
        # puts ['start', start_edge, start_edge.entityID, start_index] if debug
        puts ['edges', edges1.map(&:entityID)] if debug

        raise "Expected 4 edges, got #{edges1.size}" unless edges1.size == 4
        raise "Expected 4 edges, got #{edges2.size}" unless edges2.size == 4

        # p edges1 if debug
        # p edges2 if debug

        # p edges1.map(&:persistent_id) if debug
        # p edges2.map(&:persistent_id) if debug

        # puts '> vertices'
        # p edges1.map(&:vertices).flatten.uniq if debug
        # p edges2.map(&:vertices).flatten.uniq if debug

        average1 = average_deviance(edges1, debug)
        average2 = average_deviance(edges2, debug)

        puts if debug
        p [average1, average2] if debug
        p [average1.radians, average2.radians] if debug

        average1 <= average2
      end

      def pts_normal(pt1, pt2, pt3)
        x_axis = pt1.vector_to(pt2)
        y_axis = pt1.vector_to(pt3)
        (x_axis * y_axis).normalize
      end

      def highest_vertex
        # vertices.max { |a, b| a.position.z <=> b.position.z }

        vertices.min { |a, b| a.position.z <=> b.position.z }
        sorted = vertices.sort { |a, b|
          a.position.z <=> b.position.z
        }.last

        # local_vertices.sort { |a, b|
        #   a.position.z <=> b.position.z
        # }.last.entity
      end

      def lowest_vertex
        vertices.min { |a, b| a.position.z <=> b.position.z }
        sorted = vertices.sort { |a, b|
          a.position.z <=> b.position.z
        }.first

        # local_vertices.sort { |a, b|
        #   a.position.z <=> b.position.z
        # }.first.entity
      end

      def local_vertices
        origin = diagonal_center
        z_axis = plane_normal2
        to_plane = Geom::Transformation.new(origin, z_axis)

        vertices.map { |vertex|
          pt = vertex.position.transform(to_plane)
          Vertex.new(vertex, pt)
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

      # High/Low
      view.draw_points([@quad.highest_vertex.position], 10, 2, 'red')
      view.draw_points([@quad.lowest_vertex.position], 10, 2, 'blue')

      # Quad
      color = color = @quad.smooth_slope?(true) ? [0, 255, 0, 64] : [255, 0, 0, 64]
      draw_quad(view, @quad, color)
      n1, n2 = quad_normal_segment(view, @quad)

      # p quad.neighbours.size
      @quad.neighbours.each { |neighbour|
        color = color = neighbour.smooth_slope? ? [0, 255, 0, 64] : [255, 0, 0, 64]
        draw_quad(view, neighbour, color)

        points = quad_normal_segment(view, neighbour)
        position = view.screen_coords(points.last)
        position.y -= TEXT_OPTIONS[:size] + 5
        angle = @quad.plane_normal2.angle_between(neighbour.plane_normal2)
        angle_formatted = Sketchup.format_angle(angle)
        # sign = @quad.plane_normal2 % neighbour.plane_normal2
        sign = neighbour.plane_normal2 % @quad.plane_normal2

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
      [center, center.offset(quad.plane_normal2, size)]
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
          # center = quad.centroid
          # [center, center.offset(quad.normal, size)]
          [center, center.offset(quad.plane_normal2, size)]
          # [center, center.offset(quad.plane_normal, size)]
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
