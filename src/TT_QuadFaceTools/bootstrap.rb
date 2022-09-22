#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/vendor/error-handler/error_reporter'

module TT::Plugins::QuadFaceTools

  # TODO: Move these constants to a separate environment.rb file?
  SKETCHUP_VERSION = Sketchup.version.to_i

  # Sketchup.write_default("TT_QuadFaceTools", "ErrorServer", "sketchup.thomthom.local")
  # Sketchup.write_default("TT_QuadFaceTools", "ErrorServer", "sketchup.thomthom.net")
  server = Sketchup.read_default(PLUGIN_ID, "ErrorServer",
    "sketchup.thomthom.net")

  unless defined?(DEBUG)
    # Sketchup.write_default("TT_QuadFaceTools", "Debug", true)
    DEBUG = Sketchup.read_default(PLUGIN_ID, "Debug", false)
  end

  # Sketchup.write_default("TT_Vertex2", "DebugVersionCheck", false)
  VERSION_CHECK = Sketchup.read_default(PLUGIN_ID, "DebugVersionCheck", true)

  # Minimum version of SketchUp required to run the extension.
  MINIMUM_SKETCHUP_VERSION = 14

  ### COMPATIBILITY CHECK ### --------------------------------------------------

  if VERSION_CHECK && SKETCHUP_VERSION < MINIMUM_SKETCHUP_VERSION

    # Not localized because we don't want the Translator and related
    # dependencies to be forced to be compatible with older SketchUp versions.
    version_name = "20#{MINIMUM_SKETCHUP_VERSION}"
    message = "#{EXTENSION[:name]} require SketchUp #{version_name} or newer."
    messagebox_open = false # Needed to avoid opening multiple message boxes.
    # Defer with a timer in order to let SketchUp fully load before displaying
    # modal dialog boxes.
    UI.start_timer(0, false) {
      unless messagebox_open
        messagebox_open = true
        UI.messagebox(message)
        # Must defer the disabling of the extension as well otherwise the
        # setting won't be saved. I assume SketchUp save this setting after it
        # loads the extension.
        @extension.uncheck
      end
    }

  else # Sketchup.version

    ### ERROR HANDLER ### ------------------------------------------------------

    config = {
      :extension_id => PLUGIN_ID,
      :extension    => @ex,
      :server       => "http://#{server}/api/v1/extension/report_error",
      :support_url  => "#{PLUGIN_URL}/support",
      :debug        => DEBUG
    }
    ERROR_REPORTER = ErrorReporter.new(config)

  end # if Sketchup.version

  ### Initialization ### -----------------------------------------------------

  begin
    require "TT_QuadFaceTools/core"
  rescue Exception => exception
    TT::Plugins::QuadFaceTools::ERROR_REPORTER.handle(exception)
  end

end # module
