#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/resource'
require 'TT_QuadFaceTools/settings'


module TT::Plugins::QuadFaceTools

  MODE_ERASER = 0
  MODE_HOVER  = 1

  LEFT_MOUSE_BUTTON_FLAG = 1

  # TODO: Load on demand. Right now this loads the cursor when this file loads.
  CURSOR_ID = Resource.create_cursor('quad_edge.png', 3, 3)

  # noinspection RubyInstanceMethodNamingConvention
  class QuadEdgeTool

    def activate
      update_ui
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def resume(view)
      update_ui
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onCancel(reason, view)
      view.model.selection.clear
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onReturn(view)
      case mode
      when MODE_HOVER
        make_selection_quad_edges(view.model)
      end
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onMouseMove(flags, x, y, view)
      case mode
      when MODE_ERASER
        return unless flags & LEFT_MOUSE_BUTTON_FLAG != 0
        select_edge(x, y, view)
      when MODE_HOVER
        view.model.selection.clear
        select_edge(x, y, view)
      end
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onLButtonDown(flags, x, y, view)
      view.model.selection.clear
      select_edge(x, y, view)
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onLButtonUp(flags, x, y, view)
      make_selection_quad_edges(view.model)
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def getMenu(menu)
      menu_id = menu.add_item('Hover to Select') {
        new_mode = (mode == MODE_HOVER) ? MODE_ERASER : MODE_HOVER
        set_mode(new_mode)
      }
      menu.set_validation_proc(menu_id) {
        mode == MODE_HOVER ? MF_CHECKED : MF_ENABLED
      }
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

    def onSetCursor
      UI.set_cursor(CURSOR_ID)
    end

    private

    def update_ui
      if mode == MODE_HOVER
        Sketchup.status_text = 'Click an edge to turn it into a Quad Edge.'
      else
        Sketchup.status_text = 'Click and drag mouse to turn edges into Quad Edges.'
      end
      nil
    end

    def mode
      @mode ||= Settings.read('ToolMode', MODE_ERASER)
    end

    def set_mode(value)
      Settings.write('ToolMode', value)
      @mode = value
      update_ui
      nil
    end

    def make_selection_quad_edges(model)
      model.start_operation('Quad-Edge Properties', true)
      model.selection.grep(Sketchup::Edge) { |edge|
        quad_edge(edge)
      }
      model.commit_operation
      nil
    end

    def select_edge(x, y, view)
      edge = pick_edge(x, y, view)
      view.model.selection.add(edge) if edge
      nil
    end

    def pick_edge(x, y, view)
      ph = view.pick_helper(x, y, 5)
      ph.picked_edge
    end

    def quad_edge(edge)
      # TODO: Make this part of the QFT Entities wrapper.
      edge.soft = true
      edge.smooth = true
      edge.casts_shadows = false
      nil
    end

  end # class

end # module
