#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
module GL

  module Points
    OPEN_SQUARE     = 1
    FILLED_SQUARE   = 2
    PLUS            = 3
    CROSS           = 4
    STAR            = 5
    OPEN_TRIANGLE   = 6
    FILLED_TRIANGLE = 7
  end

  module Stipple
    SOLID_LINE      = ''.freeze
    DOTTED_LINE     = '.'.freeze
    SHORT_DASHES    = '-'.freeze
    LONG_DASHES     = '_'.freeze
    LONG_DASHES_X2  = '__'.freeze
    LONG_DASHES_X3  = '___'.freeze
    LONG_DASHES_X4  = '____'.freeze
    DASH_DOT_DASH   = '-.-'.freeze
    DOT_SPACE_DOT   = '. .'.freeze
    DASH_SPACE_DASH = '- -'.freeze
  end

end # module GL
end # module