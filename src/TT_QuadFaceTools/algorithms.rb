#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
module Algorithms

  # @param [Enumerable] enumerable
  #
  # @return [Number]
  def sum(enumerable)
    enumerable.inject(0) { |sum, x| sum + x }
  end

  # @param [Enumerable] enumerable
  #
  # @return [Array]
  def rotate(enumerable, n = 1)
    enumerable.map.with_index { |x, i|
      i2 = (i + n) % enumerable.size
      enumerable[i2]
    }
  end

end # module
end # module
