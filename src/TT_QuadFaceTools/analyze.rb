#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_Lib2/instance'


module TT::Plugins::QuadFaceTools
module Analyzer

  # @since 0.9.3
  COLOR_TRI       = Sketchup::Color.new( 72,  72, 120)
  COLOR_TRI_BACK  = Sketchup::Color.new(  9,   9,  54)
  COLOR_QUAD      = Sketchup::Color.new( 72, 120,  72)
  COLOR_QUAD_BACK = Sketchup::Color.new(  9,  54,   9)
  COLOR_NGON      = Sketchup::Color.new(144,  48,  48)
  COLOR_NGON_BACK = Sketchup::Color.new( 54,   9,   9)

  # @since 0.9.3
  def self.analyze_active_entities(colorize = false, recursive = true)
    stats = {
        :tris  => 0,
        :quads => 0,
        :ngons => 0
    }

    model = Sketchup.active_model
    TT::Model.start_operation('Colorize Quads') if colorize
    self.analyze_entities(model.active_entities, stats, colorize, recursive)
    model.commit_operation if colorize

    num_polygons = stats[:tris] + stats[:quads] + stats[:ngons]
    results  = "Triangles: #{stats[:tris]}\n"
    results << "    Quads: #{stats[:quads]}\n"
    results << "   N-Gons: #{stats[:ngons]}\n"
    results << "--------------------\n"
    results << "    Total: #{num_polygons}\n"

    # TODO: These methods are doing two functions, untangle them.
    UI.messagebox(results, MB_MULTILINE) unless colorize
    nil
  end

  # @since 0.9.3
  def self.analyze_entities(entities, stats, colorize = false, recursive = true)
    provider = EntitiesProvider.new(entities)
    provider.each { |entity|
      case entity
      when QuadFace
        stats[:quads] += 1
        if colorize
          entity.material = self.qft_material(:COLOR_QUAD)
          entity.back_material = self.qft_material(:COLOR_QUAD_BACK)
        end
      when Sketchup::Face
        case entity.vertices.size
        when 3
          stats[:tris] += 1
          if colorize
            entity.material = self.qft_material(:COLOR_TRI)
            entity.back_material = self.qft_material(:COLOR_TRI_BACK)
          end
        when 4
          # Don't think this should ever trigger. Should end up in QuadFace.
          stats[:quads] += 1
          if colorize
            entity.material = self.qft_material(:COLOR_QUAD)
            entity.back_material = self.qft_material(:COLOR_QUAD_BACK)
          end
        else
          stats[:ngons] += 1
          if colorize
            entity.material = self.qft_material(:COLOR_NGON)
            entity.back_material = self.qft_material(:COLOR_NGON_BACK)
          end
        end
      when Sketchup::Group, Sketchup::ComponentInstance
        next unless recursive
        definition = TT::Instance.definition(entity)
        self.analyze_entities(definition.entities, stats, colorize, recursive)
      else
        next
      end
    }
    nil
  end

  # Looks for existing materials and reuse that if possible. Otherwise create
  # a new one from the default color configuration.
  #
  # @param [Symbol] color_name
  # @return [Sketchup::Material]
  def self.qft_material(color_name)
    model = Sketchup.active_model
    return if model.nil?
    material_name = "QFT_#{color_name.to_s}"
    material = model.materials.at(material_name)
    return material if material
    color = self.const_get(color_name)
    material = model.materials.add(material_name)
    material.color = color
    material
  end

  # @since 0.11.0
  def self.start_live_analysis
    raise 'not supported in this SketchUp version' if Sketchup.version.to_i < 16
    model = Sketchup.active_model
    return if model.nil?
    model.remove_observer(@observer) if @observer
    @observer = MeshAnalysis.new
    model.add_observer(@observer)
    # SketchUp reuse the Ruby object for models under Windows. Use the
    # definition list instead.
    @model_observers ||= {}
    @model_observers[model.definitions] = @observer
    self.analyze_active_entities(true, false)
    nil
  end

  # @since 0.11.0
  def self.stop_live_analysis
    model = Sketchup.active_model
    return if model.nil? || @observer.nil?
    model.remove_observer(@observer)
    @model_observers ||= {}
    @model_observers.delete(model.definitions)
    nil
  end

  # @since 0.11.0
  def self.toggle_live_analysis
    if self.is_active_model_observed?
      self.stop_live_analysis
    else
      self.start_live_analysis
    end
    nil
  end

  # @since 0.11.0
  def self.is_active_model_observed?
    model = Sketchup.active_model
    return false if model.nil?
    return false if @model_observers.nil?
    @model_observers.key?(model.definitions)
  end

  # @since 0.11.0
  class MeshAnalysis < Sketchup::ModelObserver

    def onTransactionStart(model)
      analyzeModel(model)
    end

    def onTransactionCommit(model)
      analyzeModel(model)
    end

    def onTransactionAbort(model)
      analyzeModel(model)
    end

    def onTransactionUndo(model)
      analyzeModel(model)
    end

    def onTransactionRedo(model)
      analyzeModel(model)
    end

    private

    def analyzeModel(model)
      return if @suspend
      # TODO(thomthom): Don't need stats for this observer. Should clean up the
      # analyze_entities method to avoid duplicate responsibility.
      stats = {
          :tris  => 0,
          :quads => 0,
          :ngons => 0
      }
      @suspend = true
      model.start_operation('Colorize Quads', true, false, true)
      Analyzer.analyze_entities(
          model.active_entities,
          stats,
          true,  # Colorize
          false  # Recursive
      )
      model.commit_operation
      @suspend = false
      nil
    rescue Exception => exception
      ERROR_REPORTER.handle(exception)
    end

  end # class

end # module
end # module
