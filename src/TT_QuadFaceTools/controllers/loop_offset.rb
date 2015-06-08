#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/drawing_helper'
require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/geometry'


module TT::Plugins::QuadFaceTools
class LoopOffset

  COLOR_PICK_POINT = Sketchup::Color.new(255, 0, 0)

  def initialize
    # The source loop to be offset.
    @loop = nil

    # The source point on the source edge from where the offset is based.
    @origin = nil

    # The source edge in the loop from where the offset is based.
    @edge = nil

    # The face picked when picking the origin.
    @face = nil

    # The point picked on the face when picking the origin.
    @picked_point = nil

    # The point picked on the face when picking the offset.
    @offset_point = nil

    # The entities provider. Caching the known quads.
    @provider = EntitiesProvider.new
  end

  # @param [Array<Sketchup::Edge>] loop
  def loop=(loop)
    @loop = loop
    reset
  end

  def picked_loop?
    !@loop.nil?
  end

  def picked_origin?
    picked_loop? && !@origin.nil?
  end

  def picked_offset?
    picked_loop? && picked_origin? && !@offset_point.nil?
  end

  # @return [Length]
  def distance
    @origin.distance(@offset_point)
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
        @loop = loop
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
    raise 'source loop not set' if @loop.nil?
    ph = view.pick_helper(x, y)
    face = ph.picked_face
    return nil unless face
    edges = (face.edges & @loop)
    return nil unless edges.size == 1
    edge = edges[0]
    face_is_valid_pick = @provider.connected_quads(edge).any? { |quad|
      quad.faces.include?(face)
    }
    return nil unless face_is_valid_pick
    ray = view.pickray(x, y)
    @picked_point = Geom.intersect_line_plane(ray, face.plane)
    raise 'invalid pick point' unless @picked_point
    @face = face
    @edge = edge
    @origin = Geometry.project_to_edge(@picked_point, edge)
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Geom::Point3d, Nil]
  def pick_offset(x, y, view)
    ray = view.pickray(x, y)
    @offset_point = Geom.intersect_line_plane(ray, @face.plane)
  end

  # @param [Sketchup::View] view
  def draw(view)
    if @origin
      view.line_stipple = ''
      view.line_width = 1
      view.draw_points([@origin], 10, GL::Points::CROSS, COLOR_PICK_POINT)
      view.draw_points([@origin], 10, GL::Points::OPEN_SQUARE, COLOR_PICK_POINT)
    end

    if @offset_point
      view.line_stipple = ''
      view.line_width = 1
      view.draw_points([@offset_point], 10, GL::Points::CROSS, COLOR_PICK_POINT)
    end

    view
  end

  def reset
    @edge = nil
    @face = nil
    @origin = nil
    @picked_point = nil
    @offset_point = nil
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