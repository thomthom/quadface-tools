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
  
  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = 'TT_QuadFaceTools'.freeze
  PLUGIN_NAME     = 'QuadFace Tools'.freeze
  PLUGIN_VERSION  = '0.9.0'.freeze
  
  # Resource paths
  FILENAMESPACE = File.basename( __FILE__, '.rb' )
  PATH_ROOT     = File.dirname( __FILE__ ).freeze
  PATH          = File.join( PATH_ROOT, FILENAMESPACE ).freeze
  PATH_ICONS = File.join( PATH, 'icons' ).freeze
  PATH_HTML  = File.join( PATH, 'html' ).freeze
  
  
  ### EXTENSION ### ------------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    loader = File.join( PATH, 'core.rb' )
    @ex = SketchupExtension.new( PLUGIN_NAME, loader )
    @ex.description = 'Suite of tools for manipulating quad faces.'
    @ex.version     = PLUGIN_VERSION
    @ex.copyright   = 'Thomas Thomassen © 2011—2015'
    @ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension( @ex, true )
  end
  
  def self.extension
    @ex
  end
  
  end # module QuadFaceTools
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------