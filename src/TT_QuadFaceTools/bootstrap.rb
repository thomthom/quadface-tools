#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/vendor/error-handler/error_reporter'

module TT::Plugins::QuadFaceTools

  # Sketchup.write_default("TT_QuadFaceTools", "ErrorServer", "sketchup.thomthom.local")
  # Sketchup.write_default("TT_QuadFaceTools", "ErrorServer", "sketchup.thomthom.net")
  server = Sketchup.read_default(PLUGIN_ID, "ErrorServer",
    "sketchup.thomthom.net")

  unless defined?(DEBUG)
    # Sketchup.write_default("TT_QuadFaceTools", "Debug", true)
    DEBUG = Sketchup.read_default(PLUGIN_ID, "Debug", false)
  end

  config = {
    :extension_id => PLUGIN_ID,
    :extension    => @ex,
    :server       => "http://#{server}/api/v1/extension/report_error",
    :support_url  => "#{PLUGIN_URL}/support",
    :debug        => DEBUG
  }
  ERROR_REPORTER = ErrorReporter.new(config)

end # module


begin
  require "TT_QuadFaceTools/core"
rescue Exception => exception
  TT::Plugins::QuadFaceTools::ERROR_REPORTER.handle(exception)
end
