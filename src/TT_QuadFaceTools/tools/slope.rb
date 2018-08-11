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
        # @faces.map(&:vertices).flatten.uniq
        f1, f2 = @faces
        f1.outer_loop.vertices << (f2.vertices - f1.vertices).first
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
        vx * vy
      end

      def planar?
        TT::Geom3d.planar_points?(vertices)
      end

      def smooth_slope?
        return true if planar?
        # Find the vertex with the lowest Z value.
        sorted = vertices.sort { |a, b|
          a.position.z <=> b.position.z
        }
        lowest = sorted.first
        # In case of planar vertices, ensure the lowest vertex of the diagonal
        # is not chosen. Otherwise there are false positive when detecting
        # whether the slope is smooth or not.
        # edge_lowest = @edge.vertices.min { |a, b| a.position.z <=> b.position.z }
        # if lowest == edge_lowest
        #   next_vertex = sorted[1]
        #   lowest = next_vertex if next_vertex.position.z == lowest.position.z
        # end

        # ...
        lowest_z = lowest.position.z


        # low_plane = Geom.fit_plane_to_points(lowest_triangle)
        # is_semi_planar = sorted.first(3).all? { |vertex|
        #   vertex.position.z == lowest_z
        # }

        # if is_semi_planar
        #   highest = sorted.last
        #   return !@edge.vertices.include?(highest)
        # end


        all_lowest = sorted.select { |vertex| vertex.position.z == lowest_z }
        if (2..3).include?(all_lowest.size)
          highest = sorted.last
          return !@edge.vertices.include?(highest)
        end

        # lowest = vertices.min { |a, b| a.position.z <=> b.position.z }

        # The logic of slope smoothness must be inverted when the quad is
        # pointing downwards.
        smoothness = @edge.vertices.include?(lowest)
        # plane_normal % Z_AXIS > 0.0 ? !smoothness : smoothness
        normal % Z_AXIS > 0.0 ? !smoothness : smoothness
        # normal % Z_AXIS > 0.0001 ? !smoothness : smoothness

        # x = plane_normal.x.to_l >= 0.0.to_l
        # y = plane_normal.y.to_l >= 0.0.to_l
        # right_to_left = x != y
        # normal % Z_AXIS >= 0.0 ? !right_to_left : right_to_left
      end

      def highest_vertex
        vertices.max { |a, b| a.position.z <=> b.position.z }
      end

      def lowest_vertex
        # vertices.min { |a, b| a.position.z <=> b.position.z }
        sorted = vertices.sort { |a, b|
          a.position.z <=> b.position.z
        }.first
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

    # @param [Sketchup::View] view
    def draw(view)
      draw_quads(view)

      return unless @quad && @quad.valid?

      # Normal
      size = @quad.edge.length / 2.0
      # size = view.pixels_to_model(50, center)

      center = @quad.diagonal_center
      normal_segment = [center, center.offset(@quad.normal, size)]
      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = [255, 0, 0]
      view.draw(GL_LINES, normal_segment)

      # center = @quad.centroid
      normal_segment = [center, center.offset(@quad.plane_normal2, size * 1.5)]
      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = 'orange'
      view.draw(GL_LINES, normal_segment) unless @quad.plane_normal2.samedirection?(@quad.normal)
      # normal_segment = [center, center.offset(@quad.plane_normal.reverse, size * 1.5)]
      # view.drawing_color = 'purple'
      # view.draw(GL_LINES, normal_segment)

      # High/Low
      view.draw_points([@quad.highest_vertex.position], 5, 2, 'red')
      view.draw_points([@quad.lowest_vertex.position], 5, 2, 'blue')

      # Quad
      view.line_stipple = '_'
      view.line_width = 2
      view.drawing_color = 'orange'
      view.draw(GL_LINES, @quad.edge.vertices.map(&:position))
      triangles = @quad.faces.map { |face| face.vertices.map(&:position) }
      view.drawing_color = @quad.smooth_slope? ? [0, 255, 0, 64] : [255, 0, 0, 64]
      view.draw(GL_TRIANGLES, triangles.flatten)
    end

    private

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
