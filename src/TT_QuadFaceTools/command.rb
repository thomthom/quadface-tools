#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/platform'

module TT::Plugins::QuadFaceTools
  module Command

    # The supported fileformat for vector icons depend on the platform.
    VECTOR_FILETYPE = PLATFORM_OSX ? 'pdf' : 'svg'

    # SketchUp allocate the object by implementing `new` - probably part of
    # older legacy implementation when that was the norm. Because of that the
    # class cannot be sub-classed directly. This module simulates the interface
    # for how UI::Command is created. `new` will create an instance of
    # UI::Command but mix itself into the instance - effectivly subclassing it.
    # (yuck!)
    def self.new(title, &block)
      command = UI::Command.new(title) {
        begin
          block.call
        rescue Exception => exception
          ERROR_REPORTER.handle(exception)
        end
      }
      command.extend(self)
      command
    end

    # Sets the large icon for the command. Provide the full path to the raster
    # image and the method will look for a vector variant in the same folder
    # with the same basename.
    #
    # @param [String] path
    def large_icon=(path)
      super(get_icon_path(path))
    end

    # @see #large_icon
    #
    # @param [String] path
    def small_icon=(path)
      super(get_icon_path(path))
    end

    private

    def get_icon_path(path)
      return path unless Sketchup.version.to_i > 15
      vector_icon = get_vector_path(path)
      File.exist?(vector_icon) ? vector_icon : path
    end

    def get_vector_path(path)
      dir = File.dirname(path)
      basename = File.basename(path, '.*')
      File.join(dir, "#{basename}.#{VECTOR_FILETYPE}")
    end

  end # class

end # module
