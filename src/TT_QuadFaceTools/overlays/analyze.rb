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

  def initialize
    super('thomthom.quadfacetools.analyze', 'Quad Analysis')
    self.description = 'Visualizes topology structure.'

    @polygons = {
      COLOR_TRI => [],
      COLOR_QUAD => [],
      COLOR_NGON => [],
    }

    @bounds = Geom::BoundingBox.new
  end

  def start
    # puts "start (#{self})"
    start_observing
    analyze_model(Sketchup.active_model)
  end

  def stop
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

  def onActivePathChanged(model)
    analyze_model(model)
  end

  def on_setting_change(settings, key, value)
    return unless key == 'AnalyzeRecursive'

    model = Sketchup.active_model
    analyze_model(model)
  end

  private

  def start_observing
    # puts "start_observing (#{self})"
    model = Sketchup.active_model
    model.remove_observer(self)
    model.add_observer(self)
    Settings.add_observer(self)
  end

  def stop_observing
    # puts "stop_observing (#{self})"
    model = Sketchup.active_model
    model.remove_observer(self)
    Settings.remove_observer(self)
  end

  # @param [Sketchup::Face] face
  # @param [Geom::Transformation] transformation
  # @param [Array<Geom::Point3d>] triangles
  def collect_face_triangles(face, transformation, triangles)
    raise "invalid triangles array" unless triangles.is_a?(Array)

    mesh = face.mesh
    mesh.count_polygons.times { |i|
      triangle = mesh.polygon_points_at(i + 1)
      triangle.each { |pt| pt.transform!(transformation) }
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

  def analyze_recursive?
    Settings.read('AnalyzeRecursive', false)
  end

  # @param [Sketchup::Model] model
  def analyze_model(model)
    puts "analyze_model"
    puts "> analyze_recursive?: #{analyze_recursive?}"
    @polygons.each { |color, triangles|
      triangles.clear
    }
    analyze(model.active_entities, IDENTITY, recursive: analyze_recursive?)
  end

  # @param [Sketchup::Entities] entities
  # @param [Geom::Transformation] transformation
  # @param [Boolean] recursive
  def analyze(entities, transformation, recursive: false)
    # puts "Quad Analyze..."
    provider = EntitiesProvider.new(entities)
    provider.each { |entity|
      case entity
      when QuadFace
        collect_face_triangles(entity, transformation, @polygons[COLOR_QUAD])
      when Sketchup::Face
        case entity.vertices.size
        when 3
          collect_face_triangles(entity, transformation, @polygons[COLOR_TRI])
        when 4
          collect_face_triangles(entity, transformation, @polygons[COLOR_QUAD])
        else
          collect_face_triangles(entity, transformation, @polygons[COLOR_NGON])
        end
      when Sketchup::Group, Sketchup::ComponentInstance
        next unless recursive
        definition = TT::Instance.definition(entity)
        tr = transformation * entity.transformation
        analyze(definition.entities, tr, recursive: recursive)
      else
        next
      end
    }
    recompute_bounds
    entities.model.active_view.invalidate
    nil
  end

end # class
end # module
