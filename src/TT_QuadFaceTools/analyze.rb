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
  COLOR_TRI       = Sketchup::Color.new(0, 0, 192)
  COLOR_TRI_BACK  = Sketchup::Color.new(0, 0,  64)
  COLOR_QUAD      = Sketchup::Color.new(0, 192, 0)
  COLOR_QUAD_BACK = Sketchup::Color.new(0,  64, 0)
  COLOR_NGON      = Sketchup::Color.new(192, 0, 0)
  COLOR_NGON_BACK = Sketchup::Color.new( 64, 0, 0)

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
        entity.material = COLOR_QUAD if colorize
        entity.back_material = COLOR_QUAD_BACK if colorize
      when Sketchup::Face
        case entity.vertices.size
        when 3
          stats[:tris] += 1
          entity.material = COLOR_TRI if colorize
          entity.back_material = COLOR_TRI_BACK if colorize
        when 4
          # Don't think this should ever trigger. Should end up in QuadFace.
          stats[:quads] += 1
          entity.material = COLOR_QUAD if colorize
          entity.back_material = COLOR_QUAD_BACK if colorize
        else
          stats[:ngons] += 1
          entity.material = COLOR_NGON if colorize
          entity.back_material = COLOR_NGON_BACK if colorize
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
