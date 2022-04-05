require 'TT_QuadFaceTools/overlays/overlay_shim'
require 'TT_QuadFaceTools/analyze'

module TT::Plugins::QuadFaceTools
class AnalyzeOverlay < OVERLAY

  COLOR_ALPHA     = 64
  COLOR_TRI       = Sketchup::Color.new( 72,  72, 120, COLOR_ALPHA).to_a
  COLOR_TRI_BACK  = Sketchup::Color.new(  9,   9,  54, COLOR_ALPHA).to_a
  COLOR_QUAD      = Sketchup::Color.new( 72, 120,  72, COLOR_ALPHA).to_a
  COLOR_QUAD_BACK = Sketchup::Color.new(  9,  54,   9, COLOR_ALPHA).to_a
  COLOR_NGON      = Sketchup::Color.new(144,  48,  48, COLOR_ALPHA).to_a
  COLOR_NGON_BACK = Sketchup::Color.new( 54,   9,   9, COLOR_ALPHA).to_a

  attr_reader :overlay_id, :name

  def initialize
    super()
    @overlay_id = 'thomthom.quadfacetools.analyze'.freeze
    @name = 'Quad Analysis'

    @polygons = {
      COLOR_TRI => [],
      COLOR_QUAD => [],
      COLOR_NGON => [],
    }

    @bounds = Geom::BoundingBox.new
  end

  def start(view)
    # puts "start (#{self})"
    start_observing
    analyze_model(Sketchup.active_model)
  end

  def stop(view)
    # puts "stop (#{self})"
    stop_observing
  end

  def draw(view)
    @polygons.each { |color, triangles|
      view.drawing_color = color
      # view.draw(GL_TRIANGLES, triangles, normals: normals)
      view.draw(GL_TRIANGLES, triangles)
    }
  end

  def getExtents
    @bounds
  end

  def onTransactionStart(model)
    analyze_model(model)
  end

  def onTransactionCommit(model)
    analyze_model(model)
  end

  def onTransactionAbort(model)
    analyze_model(model)
  end

  def onTransactionUndo(model)
    analyze_model(model)
  end

  def onTransactionRedo(model)
    analyze_model(model)
  end

  private

  def start_observing
    # puts "start_observing (#{self})"
    model = Sketchup.active_model
    model.remove_observer(self)
    model.add_observer(self)
  end

  def stop_observing
    # puts "stop_observing (#{self})"
    model = Sketchup.active_model
    model.remove_observer(self)
  end

  # @param [Sketchup::Face] face
  # @param [Array<Geom::Point3d>] triangles
  def collect_face_triangles(face, triangles)
    raise "invalid triangles array" unless triangles.is_a?(Array)

    mesh = face.mesh
    mesh.count_polygons.times { |i|
      triangle = mesh.polygon_points_at(i + 1)
      raise "invalid triangle" unless triangles.is_a?(Array)

      triangles.concat(triangle)
    }
  end

  def recompute_bounds
    @bounds = Geom::BoundingBox.new
    @polygons.each { |type, points|
      @bounds.add(points) unless points.empty?
    }
    nil
  end

  def analyze_model(model)
    analyze(model)
  end

  def analyze(model, recursive = false)
    # puts "Quad Analyze..."
    @polygons.each { |color, triangles|
      triangles.clear
    }
    entities = model.active_entities
    provider = EntitiesProvider.new(entities)
    provider.each { |entity|
      case entity
      when QuadFace
        collect_face_triangles(entity, @polygons[COLOR_QUAD])
      when Sketchup::Face
        case entity.vertices.size
        when 3
          collect_face_triangles(entity, @polygons[COLOR_TRI])
        when 4
          collect_face_triangles(entity, @polygons[COLOR_QUAD])
        else
          collect_face_triangles(entity, @polygons[COLOR_NGON])
        end
      when Sketchup::Group, Sketchup::ComponentInstance
        next unless recursive
        # definition = TT::Instance.definition(entity)
        # self.analyze_entities(definition.entities, stats, colorize, recursive)
      else
        next
      end
    }
    recompute_bounds
    nil
  end

end # class
end # module
