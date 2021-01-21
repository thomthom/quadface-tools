module Sketchup; class ModelService; end; end unless defined?(Sketchup::ModelService)

module TT::Plugins::QuadFaceTools
  class HologramService < Sketchup::ModelService

    def self.add_mesh(triangles, normals)
      service.add_mesh(triangles, normals)
    end

    def self.service
      if @service.nil?
        @service = self.new
        model = Sketchup.active_model
        model.services.add(@service)
      end
      @service
    end

    attr_reader :meshes

    def initialize
      super('Holograms')
      @meshes = []
    end

    def start(view)
      start_observing_app
    end

    def stop(view)
      stop_observing_app
    end

    def add_mesh(triangles, normals)
      raise "#{triangles.size} vs #{normals.size}" unless triangles.size == normals.size
      @meshes << [triangles, normals]
    end

    # TT::Plugins::QuadFaceTools::HologramService.service.reset
    def reset
      @meshes.clear
    end

    def draw(view)
      view.drawing_color = view.model.rendering_options['FaceFrontColor']
      @meshes.each { |triangles, normals|
        view.draw(GL_TRIANGLES, triangles, normals: normals)
      }
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
