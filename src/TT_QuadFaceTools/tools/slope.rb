#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'set'

require 'TT_QuadFaceTools/quad_slope'

module TT::Plugins::QuadFaceTools
  class SlopeInspectTool

    def initialize
      @quad = nil
      @quads = []
    end

    def activate
      @quads = QuadSlope.find_quads(Sketchup.active_model.active_entities)
      update_ui
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def deactivate(view)
      view.invalidate
    end

    def onCancel(reason, view)
      @quads = []
      UI.start_timer(0.0, false) do
        @quads = QuadSlope.find_quads(Sketchup.active_model.active_entities)
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
      color = color = @quad.smooth_slope? ? [0, 255, 0, 64] : [255, 0, 0, 64]
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
      QuadSlope.flip_quads(quads, model)
      # TODO: Update after commit.
      @quad = nil
      @quads = QuadSlope.find_quads(model.active_entities)
      nil
    end

    def pick_quad(x, y, view)
      # TODO: Try to pick real Quad first.
      ph = view.pick_helper(x, y, 5)
      QuadSlope.create_quad_slope(ph.picked_face)
    end

  end # class
end # module
