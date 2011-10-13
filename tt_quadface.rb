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
  PLUGIN          = TT::Plugins::QuadFaceTools
  PLUGIN_ID       = 'TT_QuadFaceTools'.freeze
  PLUGIN_NAME     = 'QuadFace Tools'.freeze
  PLUGIN_VERSION  = '0.5.0'.freeze
  PLUGIN_AUTHOR   = 'ThomThom'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH        = File.join( PATH_ROOT, 'TT_QuadFaceTools' ).freeze
  PATH_ICONS  = File.join( PATH, 'Icons' ).freeze
  
  
  ### EXTENSION ### --------------------------------------------------------
  
  path = File.dirname( __FILE__ )
  core = File.join( PATH, 'core.rb' )
  @ex = SketchupExtension.new( PLUGIN_NAME, core )
  @ex.version = PLUGIN_VERSION
  @ex.copyright = 'Thomas Thomassen © 2011'
  @ex.creator = 'Thomas Thomassen (thomas@thomthom.net)'
  @ex.description = 'Suite of tools for manipulating quad faces.'
  Sketchup.register_extension( @ex, true )
  
  def self.extension
    @ex
  end
  
  
  ### LIB FREDO UPDATER ### ----------------------------------------------------
  
  def self.register_plugin_for_LibFredo6
    {   
      :name => PLUGIN_NAME,
      :author => PLUGIN_AUTHOR,
      :version => PLUGIN_VERSION.to_s,
      :date => '13 Oct 11',   
      :description => @ex.description,
      :link_info => 'https://bitbucket.org/thomthom/quadface-tools/'
    }
  end
  
end # module

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------