#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module QuadFaceTools

  ### CONSTANTS ### ------------------------------------------------------------

  # Build types
  RELEASE_BUILD     = 'r'.freeze
  DEVELOPMENT_BUILD = 'b'.freeze

  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = 'TT_QuadFaceTools'.freeze
  PLUGIN_NAME     = 'QuadFace Tools'.freeze
  PLUGIN_VERSION  = '0.10.0'.freeze
  PLUGIN_URL      = 'http://evilsoftwareempire.com/quadfacetools'.freeze
  BUILD_VERSION   = '001'.freeze
  BUILD_TYPE      = RELEASE_BUILD

  # Resource paths
  file = __FILE__.dup
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
  FILENAMESPACE = File.basename(file, '.rb')
  PATH_ROOT     = File.dirname(file).freeze
  PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze
  PATH_ICONS    = File.join(PATH, 'icons').freeze
  PATH_HTML     = File.join(PATH, 'html').freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, 'bootstrap')
    @ex = SketchupExtension.new(PLUGIN_NAME, loader)
    @ex.description = 'Suite of tools for manipulating quad faces.'
    @ex.version     = "#{PLUGIN_VERSION}.#{BUILD_VERSION}#{BUILD_TYPE}"
    @ex.copyright   = 'Thomas Thomassen © 2011—2016'
    @ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension(@ex, true)
  end

  def self.extension
    @ex
  end

  end # module QuadFaceTools
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------