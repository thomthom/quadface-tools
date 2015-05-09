#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools


  # Helper module to ease some of the communication with WebDialogs.
  # Extend the WebDialog instance or include it in a subclass.
  # 
  # Instance Extend:
  # 
  #   window = UI::WebDialog.new(window_options)
  #   window.extend( WebDialogExtensions )
  #   # ...
  # 
  # Sub-class include:
  # 
  #   class CustomWindow << UI::WebDialog
  #     include WebDialogExtensions
  #     # ...
  #   end
  #
  # @since 0.8.0
  class Window < UI::WebDialog

    # Make compatible with TT::GUI::ModalWrapper
    #
    # @since 0.8.0
    def initialize( *args )
      super
      @closing = false
      set_on_close {
        @closing = true
      }
    end

    # Wrapper that makes calling JavaScript functions cleaner and easier. A very
    # simplified version of the wrapper used in TT::GUI::Window.
    # 
    # `function` is a string with the JavaScript function name.
    # 
    # The remaining arguments are optional and will be passed to the function.
    #
    # @since 0.8.0
    def call_function( function, *args )
      # Just a simple conversion, which ensures strings are escaped.
      arguments = args.map { |value|
        if value.is_a?( Hash )
          hash_to_json( value )
        else
          value.inspect
        end
      }.join( ',' )
      function = "#{function}(#{arguments});"
      execute_script( function )
    end

    # (i) Assumes the WebDialog HTML includes `base.js`.
    # 
    # Updates the form value of the given element. Use the id attribute of the
    # form element - without the `#` prefix.
    #
    # @since 0.8.0
    def update_value( element_id, value )
      call_function( 'UI.update_value', element_id, value )
    end
    
    # (i) Assumes the WebDialog HTML includes `base.js`.
    # 
    # Updates the text of the given jQuery selector matches.
    #
    # @since 0.8.0
    def update_text( hash )
      call_function( 'UI.update_text', hash )
    end
    
    # Returns a JavaScript JSON object for the given Ruby Hash.
    #
    # @since 0.8.0
    def hash_to_json( hash )
      data = hash.map { |key, value| "#{key.inspect}: #{value.inspect}" }
      "{#{data.join(',')}}"
    end
    
    # @since 0.8.0
    def parse_params( params )
      params.split( '|||' )
    end

    # Make compatible with TT::GUI::ModalWrapper
    #
    # @since 0.8.0
    def show_window
      if visible?
        bring_to_front
      else
        show_modal
      end
    end

    # Make compatible with TT::GUI::ModalWrapper
    #
    # @since 0.8.0
    def closing?
      @closing
    end

  end # class

end # module