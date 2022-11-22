require 'TT_QuadFaceTools/overlays/analyze'
require 'TT_QuadFaceTools/overlays/hologram'

module TT::Plugins::QuadFaceTools

  class OverlaysAppObserver < Sketchup::AppObserver

    def expectsStartupModelNotifications
      true
    end

    def register_overlay(model)
      overlay = AnalyzeOverlay.new
      begin
        model.overlays.add(overlay)
      rescue ArgumentError => error
        # If the overlay was already registerred.
        warn error
      end

      # TODO: Not ready for production.
      HologramOverlay.overlay(model) if DEBUG
    end
    alias_method :onNewModel, :register_overlay
    alias_method :onOpenModel, :register_overlay

  end

  def self.register_overlays
    model = Sketchup.active_model
    return unless model.respond_to?(:overlays)

    observer = OverlaysAppObserver.new
    Sketchup.add_observer(observer)

    # In the case of installing or enabling the extension we need to
    # register the overlay.
    observer.register_overlay(model) if model
    nil
  end

end # module
