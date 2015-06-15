#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/controllers/loop_offset'


module TT::Plugins::QuadFaceTools
class OffsetTool

  module State
    PICK_LOOP   = 0
    PICK_ORIGIN = 1
    PICK_OFFSET = 2
  end

  def initialize
    @state = State::PICK_LOOP
    @loop_offset = LoopOffsetController.new
  end

  def activate
    @loop_offset.reset

    loop = find_loop_from_selection
    if loop
      @loop_offset.loop = loop
      @state = State::PICK_ORIGIN
    end

    update_vcb
  end

  # @param [Sketchup::View] view
  def deactivate(view)
    view.invalidate
  end

  # @param [Sketchup::View] view
  def resume(view)
    update_vcb
    view.invalidate
  end

  def onCancel(_reason, view)
    @loop_offset.reset
    case @state
    when State::PICK_LOOP, State::PICK_ORIGIN
      @loop_offset.loop = nil
      view.model.selection.clear
      @state = State::PICK_LOOP
    else
      @state = State::PICK_ORIGIN
    end
    view.invalidate
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  def onMouseMove(_flags, x, y, view)
    case @state
    when State::PICK_LOOP, State::PICK_ORIGIN

      if @state == State::PICK_LOOP
        loop = @loop_offset.pick_loop(x, y, view)
        set_selection(view.model.selection, loop) if loop
      end

      if @loop_offset.picked_loop?
        @loop_offset.pick_origin(x, y, view)
      end

    when State::PICK_OFFSET

      @loop_offset.pick_offset(x, y, view)

    else
      raise 'invalid tool state'
    end

    update_vcb
    view.invalidate
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  def onLButtonDown(_flags, x, y, view)
    case @state
    when State::PICK_LOOP, State::PICK_ORIGIN

      if @loop_offset.picked_loop?
        @loop_offset.pick_origin(x, y, view)
        @state = State::PICK_OFFSET
      else
        view.tooltip = 'Pick a loop before offsetting'
      end

    when State::PICK_OFFSET

      @loop_offset.pick_offset(x, y, view)
      @loop_offset.do_offset
      @loop_offset.reset
      #@state = State::PICK_ORIGIN # TODO
      @state = State::PICK_LOOP

    else
      raise 'invalid tool state'
    end

    update_vcb
    view.invalidate
  end

  # @param [Integer] key
  # @param [Sketchup::View] view
  def onKeyDown(key, _repeat, _flags, view)
    if key == COPY_MODIFIER_KEY
      @loop_offset.both_sides = !@loop_offset.both_sides
    end
    view.invalidate
  end

  # @param [Sketchup::View] view
  def draw(view)
    @loop_offset.draw(view)
  end

  private

  def update_vcb
    Sketchup.vcb_label = 'Distance'
    if @loop_offset.picked_offset?
      Sketchup.vcb_value = @loop_offset.distance
    end
    nil
  end

  # @return [Array<Sketchup::Edge>, Nil]
  def find_loop_from_selection
    model = Sketchup.active_model
    edges = model.selection.grep(Sketchup::Edge)
    return nil if edges.empty?
    provider = EntitiesProvider.new
    loop = provider.find_edge_loop(edges.first)
    return nil if (edges - loop).size > 0
    loop & edges
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Sketchup::View] view
  #
  # @return [Geom::Point3d, Nil]
  def pick_loop(x, y, view)
    input_point = view.inputpoint(x, y)
    edge = input_point.edge
    if edge
      provider = EntitiesProvider.new
      loop = provider.find_edge_loop(edge)
      set_selection(view.model.selection, loop)
      return loop
    end
    nil
  end

  # @param [Sketchup::Selection] selection
  # @param [Array<Sketchup::Edge>] entities
  #
  # @return [Boolean]
  def set_selection(selection, entities)
    entities = [] if entities.nil?
    if (entities & selection.to_a) == entities
      false
    else
      selection.clear
      selection.add(entities)
      true
    end
  end

end # class
end # module