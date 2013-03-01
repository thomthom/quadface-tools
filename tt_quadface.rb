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
  PLUGIN          = self
  PLUGIN_ID       = 'TT_QuadFaceTools'.freeze
  PLUGIN_NAME     = 'QuadFace Tools'.freeze
  PLUGIN_VERSION  = '0.8.0'.freeze
  PLUGIN_AUTHOR   = 'ThomThom'.freeze
  
  # Version information
  RELEASE_DATE    = '01 Mar 13'.freeze
  
  # Resource paths
  PATH_ROOT  = File.dirname( __FILE__ ).freeze
  PATH       = File.join( PATH_ROOT, 'TT_QuadFaceTools' ).freeze
  PATH_ICONS = File.join( PATH, 'icons' ).freeze
  PATH_HTML  = File.join( PATH, 'html' ).freeze
  
  
  ### EXTENSION ### ------------------------------------------------------------
  
  path = File.dirname( __FILE__ )
  core = File.join( PATH, 'core.rb' )
  @ex = SketchupExtension.new( PLUGIN_NAME, core )
  @ex.version     = PLUGIN_VERSION
  @ex.copyright   = 'Thomas Thomassen © 2011–2013'
  @ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
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
      :version => PLUGIN_VERSION,
      :date => RELEASE_DATE,
      :description => @ex.description,
      :link_info => 'https://bitbucket.org/thomthom/quadface-tools/'
    }
  end
  
end # module

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------