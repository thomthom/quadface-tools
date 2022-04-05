module TT::Plugins::QuadFaceTools

  unless defined?(OVERLAY)
    OVERLAY = if defined?(Sketchup::Overlay)
      Sketchup::Overlay
    else
      require 'TT_QuadFaceTools/overlays/mock_overlay'
      MockOverlay
    end
  end

end # module
