#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/drawing_helper'
require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/geometry'
require 'TT_QuadFaceTools/loop_offset'
require 'TT_QuadFaceTools/settings'


module TT::Plugins::QuadFaceTools
class LoopOffsetController

  THIN_LINE  = 1
  THICK_LINE = 2

  PICK_POINT_SIZE = 10
  POINT_SIZE = 6

  POLYGON_ALPHA_NORMAL = 16
  POLYGON_ALPHA_HIGHLIGHT = 64


  def initialize
    # The entities provider. Caching the known quads.
    @provider = EntitiesProvider.new

    # The calculated loop offset.
    @offset = LoopOffset.new(@provider)

    # The relevant face under the cursor which determines which side of the
    # loop the offset will be.
    @picked_face = nil

    # The point picked on the face when picking the offset.
    @offset_point = nil

    # The valid neighbouring faces to the loop.
    @loop_faces = []

    # Toggles debug mode.
    # TT::Plugins::QuadFaceTools::Settings.write('DebugOffset', true)
    @debug = Settings.read('DebugOffset', false)
  end

  # @return [Array<Sketchup::Edge>] loop
  def loop
    @offset.loop
  end

  # @param [Array<Sketchup::Edge>] loop
  def loop=(loop)
    @offset.loop = loop

    @loop_faces.clear
    loop.each { |edge|
      faces = @provider.get(edge.faces)
      @loop_faces.concat(faces)
    }
    @loop_faces.uniq!

    reset
  end

  def picked_loop?
    !@offset.loop.nil?
  end

  def picked_origin?
    picked_loop? && !@offset.origin.nil?
  end

  def picked_offset?
    picked_loop? && picked_origin? && !@offset_point.nil?
  end

  # @return [Length]
  def distance
    point_on_loop = @offset_point.project_to_line(@offset.start_edge.line)
    point_on_loop.distance(@offset_point)
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Array<Sketchup::Edge>, Nil]
  def pick_loop(x, y, view)
    input_point = view.inputpoint(x, y)
    edge = input_point.edge
    unless valid_pick_edge?(edge)
      edge = find_loop_start(x, y, view)
    end
    if edge
      edge_loop = @provider.find_edge_loop(edge)
      if edge_loop
        self.loop = edge_loop
        return edge_loop
      end
    end
    nil
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Geom::Point3d, Nil]
  def pick_origin(x, y, view)
    picked_point, edge, face = pick_face(x, y, view)
    if picked_point && edge && face
      @picked_face = face
      @offset.start_quad = face
      @offset.start_edge = edge
      @offset.origin = Geometry.project_to_edge(picked_point, edge)
    end
    nil
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Geom::Point3d, Nil]
  def pick_offset(x, y, view)
    # Compute the offset point and distance.
    ray = view.pickray(x, y)
    @offset_point = Geom.intersect_line_plane(ray, @picked_face.plane)
    @offset.distance = distance
    # Check if we switched which side to offset from.
    point_on_line = offset_origin
    quad1 = @offset.start_quad
    quad2 = quad1.next_face(@offset.start_edge)
    edge_vector = @offset.start_edge.line[1]
    vector1 = @offset.origin.vector_to(quad1.centroid)
    vector2 = @offset.origin.vector_to(point_on_line)
    cross1 = edge_vector * vector1
    cross2 = edge_vector * vector2
    if cross1.dot(cross2) < 0.0
      if quad2
        # When there is an opposite quad we allow the offset to switch side.
        @picked_face = quad2.faces.find { |f|
          (f.edges | @offset.loop).size > 0
        }
        @offset.start_quad = quad2
      else
        # When there is no opposite quad the offset is capped to zero.
        @offset.distance = 0.to_l
      end
    end
    nil
  end

  # @param [Sketchup::View] view
  def draw(view)

    # Visualize the quad representing the start and side for the offset.
    if @offset.start_quad
      points = @offset.start_quad.vertices.map { |vertex| vertex.position }
      view.drawing_color = selection_color(view, POLYGON_ALPHA_HIGHLIGHT)
      view.draw(GL_POLYGON, points)
    end

    # Visualize the faces that neighbours to the loop.
    unless @loop_faces.empty?
      triangles = []
      faces = @loop_faces.dup
      faces.delete(@offset.start_quad)
      faces.each { |face|
        mesh = face.mesh
        mesh.count_polygons.times { |i|
          triangles.concat(mesh.polygon_points_at(i + 1))
        }
      }
      view.drawing_color = selection_color(view, POLYGON_ALPHA_NORMAL)
      view.draw(GL_TRIANGLES, triangles)
    end

    # Visualize the picked start point on the loop.
    if @offset.origin
      points = [@offset.origin]
      view.line_stipple = GL::Stipple::SOLID_LINE
      view.line_width = THIN_LINE
      view.draw_points(points, PICK_POINT_SIZE, GL::Points::CROSS,
                       selection_color(view))
      view.draw_points(points, PICK_POINT_SIZE, GL::Points::OPEN_SQUARE,
                       selection_color(view))
    end

    # Visualize the offset position where the offset loop will intersect.
    if @offset_point
      view.line_stipple = GL::Stipple::SOLID_LINE
      view.line_width = THIN_LINE
      view.draw_points([@offset_point], POINT_SIZE, GL::Points::CROSS,
                       selection_color(view))
    end

    # Visualize the projections for the offset point relative to the offset
    # loop and pick origin.
    if @offset.origin && @offset.start_edge && @offset_point
      point_on_line = offset_origin

      view.line_width = THIN_LINE
      view.line_stipple = GL::Stipple::SOLID_LINE
      view.draw_points([point_on_line], POINT_SIZE, GL::Points::CROSS,
                       selection_color(view))

      view.line_stipple = GL::Stipple::DOTTED_LINE
      view.draw(GL_LINES, @offset.origin, point_on_line)

      view.line_stipple = GL::Stipple::LONG_DASHES
      view.draw(GL_LINES, @offset_point, point_on_line)
    end

    # Visualize the centroids for the starting quad and it's opposite neighbour.
    if @debug && @offset.start_quad
      points = []
      # Start quad centroid.
      quad1 = @offset.start_quad
      points << quad1.centroid
      # Opposite centroid.
      quad2 = quad1.next_face(@offset.start_edge)
      points << quad2.centroid if quad2
      # Just a simple cross.
      view.line_width = THIN_LINE
      view.line_stipple = GL::Stipple::SOLID_LINE
      view.draw_points(points, POINT_SIZE, GL::Points::PLUS, 'purple')
    end

    # Visualize the offset edges.
    if @offset.positions
      points = @offset.positions
      # Visualize edges.
      view.line_stipple = GL::Stipple::SOLID_LINE
      view.line_width = THIN_LINE
      view.drawing_color = @debug ? 'red' : edge_color(view)
      view.draw(GL_LINE_STRIP, points)
      # Visualize points and their order.
      if @debug
        view.line_width = THIN_LINE
        view.draw_points(points, POINT_SIZE, GL::Points::CROSS, 'red')
        points.each_with_index { |pt, i|
          pt2d = view.screen_coords(pt)
          view.draw_text(pt2d, "#{i}")
        }
      end
    end

    view
  end

  def reset
    @picked_face = nil
    @offset_point = nil
    @offset.origin = nil
    @offset.start_edge = nil
    @offset.start_quad = nil
    @offset.distance = nil
    nil
  end

  private

  # @param [Sketchup::View] view
  #
  # @return [Sketchup::Color]
  def edge_color(view)
    view.model.rendering_options['ForegroundColor']
  end

  # @param [Sketchup::View] view
  #
  # @return [Sketchup::Color]
  def selection_color(view, alpha = 255)
    color = view.model.rendering_options['HighlightColor']
    color.alpha = alpha
    color
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Sketchup::Edge, Nil]
  def find_loop_start(x, y, view)
    ph = view.pick_helper(x, y)
    ph.all_picked.find { |entity|
      valid_pick_edge?(entity)
    }
  end

  # @return [Array(Geom::Point3d, Geom::Vector3d)]
  def offset_line
    [@offset_point, @offset.start_edge.line[1]]
  end

  # @return [Geom::Point3d]
  def offset_origin
    @offset.origin.project_to_line(offset_line)
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Geom::Point3d, Nil]
  def pick_face(x, y, view)
    raise 'source loop not set' if @offset.loop.nil?
    ph = view.pick_helper(x, y)
    face = ph.picked_face
    return nil unless face
    edges = (face.edges & @offset.loop)
    return nil unless edges.size == 1
    edge = edges[0]
    face_is_valid_pick = @provider.connected_quads(edge).any? { |quad|
      quad.faces.include?(face)
    }
    return nil unless face_is_valid_pick
    ray = view.pickray(x, y)
    picked_point = Geom.intersect_line_plane(ray, face.plane)
    raise 'invalid pick point' unless picked_point
    [picked_point, edge, face]
  end

  # @param [Sketchup::Edge] edge
  def valid_pick_edge?(edge)
    return false unless edge.is_a?(Sketchup::Edge)
    return false unless edge.parent.entities == edge.model.active_entities
    return false if @provider.is_diagonal?(edge)
    unless edge.model.rendering_options['DrawHidden']
      return false if !edge.layer.visible? || edge.hidden? || edge.soft?
    end
    true
  end

end # class
end # module
