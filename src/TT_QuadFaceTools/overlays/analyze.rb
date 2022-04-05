require 'TT_QuadFaceTools/overlays/overlay_shim'
require 'TT_QuadFaceTools/analyze'

module TT::Plugins::QuadFaceTools
class AnalyzeOverlay < OVERLAY

  attr_reader :overlay_id, :name

  def initialize
    super()
    @overlay_id = 'thomthom.quadfacetools.analyze'.freeze
    @name = 'Quad Analysis'
  end

end # class
end # module
