#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools

  PLATFORM_OSX = (Object::RUBY_PLATFORM =~ /darwin/i) ? true : false
  PLATFORM_WIN = !PLATFORM_OSX

end # module
