require 'TT_QuadFaceTools/overlays/analyze'
require 'TT_QuadFaceTools/overlays/hologram'

module TT::Plugins::QuadFaceTools

  class OverlaysAppObserver < Sketchup::AppObserver

    def expectsStartupModelNotifications
      true
    end

    def register_overlay(model)
      model.overlays.add(AnalyzeOverlay.new)
      HologramOverlay.overlay(model)
    end
    alias_method :onNewModel, :register_overlay
    alias_method :onOpenModel, :register_overlay

  end

  def self.register_overlays
    model = Sketchup.active_model
    return unless model.respond_to?(:overlays)

    observer = OverlaysAppObserver.new
    Sketchup.add_observer(observer)
    nil
  end

end # module
