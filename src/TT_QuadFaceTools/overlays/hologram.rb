module TT::Plugins::QuadFaceTools
  unless defined?(OVERLAY)
    OVERLAY = if defined?(Sketchup::Overlay)
      Sketchup::Overlay
    else
      require 'TT_QuadFaceTools/overlays/mock_overlay'
      MockOverlay
    end
  end

  class HologramAppObserver < Sketchup::AppObserver

    def expectsStartupModelNotifications
      true
    end

    def register_overlay(model)
      HologramOverlay.overlay(model)
    end
    alias_method :onNewModel, :register_overlay
    alias_method :onOpenModel, :register_overlay

  end

  class HologramOverlay < OVERLAY

    def self.add_mesh(triangles, normals)
      overlay.add_mesh(triangles, normals)
    end

    def self.overlay(model = Sketchup.active_model)
      @overlays ||= {}
      overlay = self.new
      model.overlays.add(overlay)
      @overlays[model] = overlay
      overlay
    end

    def self.register_overlays
      model = Sketchup.active_model
      return unless model.respond_to?(:overlays)

      observer = HologramAppObserver.new
      Sketchup.add_observer(observer)
      nil
    end

    attr_reader :overlay_id, :name
    attr_reader :meshes

    def initialize
      super()
      @overlay_id = 'thomthom.quadfacetools.hologram'.freeze
      @name = 'Holograms'
      @meshes = []
      @bounds = Geom::BoundingBox.new
    end

    def start(view)
      start_observing_app
    end

    def stop(view)
      stop_observing_app
    end

    # @param [Array<Geom::Point3d>] triangles
    # @param [Array<Geom::Vector3d>] normals
    def add_mesh(triangles, normals)
      raise "#{triangles.size} vs #{normals.size}" unless triangles.size == normals.size
      @meshes << [triangles, normals]
      @bounds.add(triangles)
    end

    # TT::Plugins::QuadFaceTools::HologramOverlay.overlay.reset
    def reset
      @meshes.clear
      @bounds = Geom::BoundingBox.new
    end

    def draw(view)
      view.drawing_color = view.model.rendering_options['FaceFrontColor']
      @meshes.each { |triangles, normals|
        view.draw(GL_TRIANGLES, triangles, normals: normals)
      }
    end

    def getExtents
      @bounds
    end

    def onNewModel(model)
      reset
    end

    def onOpenModel(model)
      reset
    end

    private

    def start_observing_app
      return unless Sketchup.platform == :platform_win
      Sketchup.remove_observer(self)
      Sketchup.add_observer(self)
    end

    def stop_observing_app
      return unless Sketchup.platform == :platform_win
      Sketchup.remove_observer(self)
    end

  end
end
