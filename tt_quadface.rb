#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT; end
module TT::Plugins; end
module TT::Plugins::QuadFaceTools
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  ID          = 'TT_QuadFaceTools'.freeze
  VERSION     = TT::Version.new(0,1,0).freeze
  PLUGIN_NAME = 'QuadFace Tools'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH        = File.join( PATH_ROOT, 'TT_QuadFaceTools' ).freeze
  PATH_ICONS  = File.join( PATH, 'Icons' ).freeze
  
  
  ### EXTENSION ### --------------------------------------------------------
  
  path = File.dirname( __FILE__ )
  core = File.join( PATH, 'core.rb' )
  ex = SketchupExtension.new( PLUGIN_NAME, core )
  ex.version = VERSION
  ex.copyright = 'Thomas Thomassen © 2011'
  ex.creator = 'Thomas Thomassen (thomas@thomthom.net)'
  ex.description = 'Suite of tools for manipulating quad faces.'
  Sketchup.register_extension( ex, true )
  
end # module

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------