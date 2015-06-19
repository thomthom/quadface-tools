#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/window'


module TT::Plugins::QuadFaceTools
class ObjImportOptions < Window

  # @return [Hash{Symbol => Object}]
  attr_reader :results

  attr_accessor :options

  # TODO: Kludge alert! This should re refactored into the Window class itself.
  # @return [TT::GUI::ModalWrapper]
  attr_reader :modal_window

  def initialize(&block)
    html_source = File.join(PATH_HTML, 'importer.html')

    @options = {}

    window_options = {
        :dialog_title     => 'Import OBJ Options',
        :preferences_key  => false,
        :scrollable       => false,
        :resizable        => false,
        :left             => 500,
        :top              => 300,
        :width            => 360,
        :height           => 170
    }
    if TT::System::PLATFORM_IS_OSX
      window_options[:height] += 20
    end

    super(window_options)
    set_size(window_options[:width], window_options[:height])
    self.navigation_buttons_enabled = false
    @modal_window = TT::GUI::ModalWrapper.new(self)

    add_action_callback('Window_Ready') { |dialog, _params|
      if TT::System.is_windows?
        TT::Win32.window_no_resize(window_options[:dialog_title])
      end
      dialog.update_value('chkSwapYZ', options[:swap_yz])
      dialog.update_value('lstUnits',  options[:units])
    }

    @results = nil
    add_action_callback('Event_Accept') { |dialog, _params|
      # Get data from webdialog.
      @results = {
        :swap_yz => dialog.get_element_value('chkSwapYZ'),
        :units   => dialog.get_element_value('lstUnits')
      }
      # Convert to Ruby values.
      @results[:swap_yz] = (@results[:swap_yz] == 'true')
      @results[:units]   = @results[:units].to_i
      @modal_window.close
      if TT::System::PLATFORM_IS_OSX
        block.call(results)
      end
      Sketchup.active_model.active_view.invalidate # OSX
    }

    add_action_callback('Event_Cancel') { |_dialog, _params|
      @modal_window.close
      Sketchup.active_model.active_view.invalidate # OSX
    }

    set_on_close {
      @modal_window.close
      Sketchup.active_model.active_view.invalidate # OSX
    }

    set_file(html_source)
  end

end # class
end # module
