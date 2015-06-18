#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/importers/mtl'
require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/vertex_cache'


module TT::Plugins::QuadFaceTools
class ObjImporter < Sketchup::Importer

  module ImportResult
    SUCCESS = 0
    FAILURE = 1
  end

  # This method is called by SketchUp to determine the description that
  # appears in the File > Import dialog's pull-down list of valid
  # importers.
  #
  # @return [String]
  def description
    "OBJ Files - #{PLUGIN_NAME} (*.obj)"
  end

  # This method is called by SketchUp to determine what file extension
  # is associated with your importer.
  #
  # @return [String]
  def file_extension
    'obj'
  end

  # This method is called by SketchUp to get a unique importer id.
  #
  # @return [String]
  def id
    'com.sketchup.importers.obj_quadfacetools'
  end

  # This method is called by SketchUp to determine if the "Options"
  # button inside the File > Import dialog should be enabled while your
  # importer is selected.
  #
  # @return [Boolean]
  def supports_options?
    false
  end

  # This method is called by SketchUp when the user clicks on the
  # "Options" button inside the File > Import dialog. You can use it to
  # gather and store settings for your importer.
  #
  # @return [Nil]
  def do_options
    # Todo: Add options:
    # * Unit
    # * Use materials (slower)
    # * Ignore materials (faster)
    # * Triangulate quads
    nil
  end

  # This method is called by SketchUp after the user has selected a file
  # to import. This is where you do the real work of opening and
  # processing the file.
  #
  # @param [String] filename
  # @param [Boolean] show_summary
  #
  # @return [integer]
  def load_file(filename, show_summary)
    base_path = File.dirname(filename)
    model = Sketchup.active_model
    model.start_operation('Import OBJ', true)
    group = model.active_entities.add_group
    group.name = File.basename(filename)
    root_entities = group.entities
    entities = root_entities
    # OBJ files uses 1-based indicies.
    materials = MtlParser.new(model, base_path)
    vertex_cache = VertexCache.new
    vertex_cache.index_base = 1
    material = nil
    stats = Statistics.new
    Sketchup.status_text = 'Importing OBJ file...'
    # @see http://paulbourke.net/dataformats/obj/
    # @see http://www.martinreddy.net/gfx/3d/OBJ.spec
    File.open(filename, 'r') { |file|
      file.each_line { |line|
        # Filter out comments.
        next if line.start_with?('#')
        # Filter out empty lines.
        next if line.strip.empty?
        # Parse the line data and extract the line token.
        data = line.split(/\s+/)
        token = data.shift
        case token
        when 'v'
          # Read the vertex data.
          x = data.x.to_f
          y = data.y.to_f
          z = data.z.to_f
          vertex_cache.add_vertex(x, y, z)
        when 'vt'
          # Read the vertex texture data.
          u = data.x.to_f
          v = (data.y || 0.0).to_f
          w = (data.z || 0.0).to_f
          vertex_cache.add_uvw(u, v, w)
        when 'p'
          # Represent points as construction points.
          data.each { |n|
            v = n.to_i
            point = vertex_cache.get_vertex(v)
            entities.add_cpoint(point)
            stats.points += 1
          }
        when 'l'
          # Create edges ("lines").
          points = data.each { |triplet|
            v = parse_triplet(triplet)[0]
            vertex_cache.get_vertex(v)
          }
          entities.add_edges(points)
          stats.lines += 1
        when 'f'
          # Crease polygon faces.
          points = []
          mapping = []
          data.each { |triplet|
            v, vt = parse_triplet(triplet)
            point = vertex_cache.get_vertex(v)
            points << point
            if vt
              uvw = vertex_cache.get_uvw(vt)
              mapping << point
              mapping << TT::UVQ.normalize(uvw)
            end
          }
          create_face(entities, points, material, mapping)
          stats.faces += 1
        when 'o'
          group = root_entities.add_group
          group.name = data[0] unless data[0].empty?
          entities = group.entities
          next
        when 's'
          # TODO: Smoothing groups.
          puts line
          next
        when 'mtllib'
          data.each { |library|
            library_file = find_file(library, filename)
            materials.read(library_file)
          }
          next
        when 'usemtl'
          material = materials.get(data[0])
        else
          # Any other token is either unknown or not supported. No errors is
          # raised as the importer attempt to import what it can.
          puts "Skipping token: #{token}"
        end
      }
    }
    model.commit_operation
    Sketchup.status_text = ''
    # Display summary back to the user
    if show_summary
      message = "OBJ Import Results\n"
      message << "\n"
      # TODO:
      message << "Points: #{stats.points}\n"
      message << "Lines: #{stats.lines}\n"
      message << "Faces: #{stats.faces}\n"
      message << "Materials: #{materials.used_materials}\n"
      UI.messagebox(message, MB_MULTILINE)
    end
    ImportResult::SUCCESS
  rescue => error
    p error
    puts error.backtrace.join("\n")
    model.abort_operation
    ImportResult::FAILURE
  end

  private

  Statistics = Struct.new(:points, :lines, :faces) do
    def initialize(*args)
      super(*args)
      self.points ||= 0
      self.lines  ||= 0
      self.faces  ||= 0
    end
  end

  # @param [Sketchup::Entities] entities
  # @param [Array<Geom::Point3d>] points
  # @param [Sketchup::Material, Nil] material
  # @param [Array<Geom::Point3d>] mapping
  #
  # @return [Sketchup::Face, QuadFace]
  def create_face(entities, points, material, mapping)
    if TT::Geom3d.planar_points?(points)
      face = entities.add_face(points)
      if textured?(material) && !mapping.empty?
        face.position_material(material, mapping, true)
      else
        face.material = material
      end
    elsif points.size == 4
      provider = EntitiesProvider.new([], entities)
      face = provider.add_quad(points)
      if textured?(material) && !mapping.empty?
        vertices = sort_vertices(face.vertices, points)
        quad_mapping = {}
        vertices.each_with_index { |vertex, i|
          uvw = mapping[(i * 2) + 1]
          quad_mapping[vertex] = uvw
        }
        face.set_uv(quad_mapping)
      else
        face.material = material
      end
    else
      raise 'cannot import n-gons which are not planar'
    end
    face
  rescue
    p points
    raise
  end

  # If the given filename isn't found it's assumed to be relative to the
  # second argument provided.
  #
  # @param [String] filename
  # @param [String] relative_to
  #
  # @return [String]
  def find_file(filename, relative_to)
    return File.expand_path(filename) if File.exist?(filename)
    path = File.dirname(relative_to)
    File.join(path, filename)
  end

  # @param [Sketchup::Material] material
  def textured?(material)
    return false if material.nil?
    material && material.texture
  end

  # @param [Array<String>] data
  #
  # @return [Array<Integer>]
  def parse_triplet(data)
    data.split('/').map { |n| n.to_i }
  end

  # @param [Array<Sketchup::Vertex>] vertices
  # @param [Array<Geom::Point3d>] order_by_points
  #
  # @return [Array<Sketchup::Vertex>]
  def sort_vertices(vertices, order_by_points)
    order_by_points.map { |point|
      vertex = vertices.find { |vertex| vertex.position == point }
      raise 'unable to sort vertices' if vertex.nil?
      vertex
    }
  end

end # class
end # module
