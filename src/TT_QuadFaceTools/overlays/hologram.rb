module TT::Plugins::QuadFaceTools
  unless defined?(OVERLAY)
    OVERLAY = if defined?(Sketchup::Overlay)
      Sketchup::Overlay
    else
      require 'TT_QuadFaceTools/overlays/mock_overlay'
      MockOverlay
    end
  end

  class HologramOverlay < OVERLAY

    def self.add_mesh(triangles, normals)
      overlay.add_mesh(triangles, normals)
    end

    def self.overlay
      if @overlay.nil?
        @overlay = self.new
        model = Sketchup.active_model
        model.overlays.add(@overlay)
      end
      @overlay
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
