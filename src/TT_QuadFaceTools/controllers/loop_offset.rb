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


module TT::Plugins::QuadFaceTools
class LoopOffsetController

  COLOR_PICK_POINT = Sketchup::Color.new(255, 0, 0)

  def initialize
    # The calculated loop offset.
    @offset = LoopOffset.new

    # The relevant face under the cursor which determines which side of the
    # loop the offset will be.
    @picked_face = nil

    # The point picked on the face when picking the offset.
    @offset_point = nil

    # The entities provider. Caching the known quads.
    @provider = EntitiesProvider.new
  end

  # @param [Array<Sketchup::Edge>] loop
  def loop=(loop)
    @offset.loop = loop
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
      loop = @provider.find_edge_loop(edge)
      if loop
        @offset.loop = loop
        return loop
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
    @picked_face = face
    @offset.start_quad = face
    @offset.start_edge = edge
    @offset.origin = Geometry.project_to_edge(picked_point, edge)
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Geom::Point3d, Nil]
  def pick_offset(x, y, view)
    ray = view.pickray(x, y)
    @offset_point = Geom.intersect_line_plane(ray, @picked_face.plane)
    @offset.distance = distance
  end

  # @param [Sketchup::View] view
  def draw(view)

    if @offset.start_quad # DEBUG
      points = @offset.start_quad.vertices.map { |vertex| vertex.position }
      view.drawing_color = [0, 0, 255, 64]
      view.draw(GL_POLYGON, points)
    end

    if @offset.origin
      points = [@offset.origin]
      view.line_stipple = ''
      view.line_width = 1
      view.draw_points(points, 10, GL::Points::CROSS, COLOR_PICK_POINT)
      view.draw_points(points, 10, GL::Points::OPEN_SQUARE, COLOR_PICK_POINT)
    end

    if @offset_point
      view.line_stipple = ''
      view.line_width = 1
      view.draw_points([@offset_point], 10, GL::Points::CROSS, COLOR_PICK_POINT)
    end

    if @offset.positions
      points = @offset.positions
      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = 'red'
      view.draw(GL_LINE_STRIP, points)
      view.draw_points(points, 10, GL::Points::CROSS, COLOR_PICK_POINT)
    end

    view
  end

  def reset
    @picked_face = nil
    @offset_point = nil
    @offset.origin = nil
    @offset.start_edge = nil
    @offset.start_quad = nil
    nil
  end

  private

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
