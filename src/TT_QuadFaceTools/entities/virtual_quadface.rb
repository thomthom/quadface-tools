#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/entities/quadface'


module TT::Plugins::QuadFaceTools
class VirtualQuadFace < QuadFace

  class InvalidQuadFace < StandardError; end

  # @param [Sketchup::Face] triangle1
  # @param [Sketchup::Face] triangle2
  def initialize(triangle1, triangle2)
    unless triangle1.is_a?(Sketchup::Face) && triangle2.is_a?(Sketchup::Face)
      raise(InvalidQuadFace, 'Invalid faces.')
    end
    @faces = [triangle1, triangle2]
  end

  # @return [Array<Sketchup::Edge>]
  def edges
    triangle1, triangle2 = @faces
    divider = triangle1.edges & triangle2.edges
    (triangle1.edges + triangle2.edges) - divider
  end

end # class
end # module
