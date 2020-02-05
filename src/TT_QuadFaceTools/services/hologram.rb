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

  end
end
