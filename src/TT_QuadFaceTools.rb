#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'json'

require 'sketchup.rb'
require 'extensions.rb'

module TT
module Plugins
module QuadFaceTools

  file = __FILE__.dup
  # Account for Ruby encoding bug under Windows.
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
  # Support folder should be named the same as the root .rb file.
  folder_name = File.basename(file, '.*')

  # Path to the root .rb file (this file).
  PATH_ROOT = File.dirname(file).freeze

  # Path to the support folder.
  PATH = File.join(PATH_ROOT, folder_name).freeze

  # Resource paths.
  PATH_ICONS    = File.join(PATH, 'icons').freeze
  PATH_HTML     = File.join(PATH, 'html').freeze

  # Extension information.
  extension_json_file = File.join(PATH, 'extension.json')
  extension_json = File.read(extension_json_file)
  EXTENSION = ::JSON.parse(extension_json, symbolize_names: true).freeze

  # Compatibility constants.
  # TODO: Refactor out these.
  PLUGIN          = self
  PLUGIN_ID       = EXTENSION[:product_id]
  PLUGIN_NAME     = EXTENSION[:name]
  PLUGIN_VERSION  = EXTENSION[:version]
  PLUGIN_URL      = EXTENSION[:url]

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, 'bootstrap')
    @ex = SketchupExtension.new(EXTENSION[:name], loader)
    @ex.description = EXTENSION[:description]
    @ex.version     = EXTENSION[:version]
    @ex.copyright   = EXTENSION[:copyright]
    @ex.creator     = EXTENSION[:creator]
    Sketchup.register_extension(@ex, true)
  end

  def self.extension
    @ex
  end

end # module QuadFaceTools
end # module Plugins
end # module TT

file_loaded(__FILE__)
