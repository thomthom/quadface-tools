#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/importers/mtl'
require 'TT_QuadFaceTools/ui/obj_import_options'
require 'TT_QuadFaceTools/entities'
require 'TT_QuadFaceTools/unit_helper'
require 'TT_QuadFaceTools/vertex_cache'


module TT::Plugins::QuadFaceTools
class ObjImporter < Sketchup::Importer

  include UnitHelper

  IMPORTER_PREF_KEY = "#{PLUGIN_ID}\\Importer\\OBJ".freeze

  SWAP_YZ_TRANSFORM = Geom::Transformation.axes(
      ORIGIN, X_AXIS, Z_AXIS, Y_AXIS.reverse
  ).freeze

  class ObjEncodingError < StandardError; end

  attr_accessor :stats

  def initialize(parse_only: false)
    @parse_only = parse_only
    @stats = nil
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
    true
  end

  # This method is called by SketchUp when the user clicks on the
  # "Options" button inside the File > Import dialog. You can use it to
  # gather and store settings for your importer.
  #
  # @return [Nil]
  def do_options
    options = get_options
    @option_window ||= ObjImportOptions.new { |results|
      process_options(results)
    }
    @option_window.options = options
    @option_window.modal_window.show
    process_options(@option_window.results) if TT::System::PLATFORM_IS_WINDOWS
    nil
  rescue Exception => exception
    ERROR_REPORTER.handle(exception)
  end

  Context = Struct.new(
    :filename,

    :options,

    :root_entities,

    :parent_entities,

    # The current Sketchup::Entities collection new entities should be added to.
    :entities,

    # Material manager for the OBJ file being parsed.
    :materials,

    # The current material which should be applied to geometry.
    :material,

    # List of vertices defined for the OBJ file.
    # OBJ files uses 1-based indicies.
    :vertex_cache,

    # A hash with smoothing group numbers mapping to the faces within the same
    # smoothing group.
    :smoothing_groups,

    # The current smoothing group new faces should be added to unless its Nil.
    :smoothing_group,

    :custom_encodings,
    :encoding,
  )

  # This method is called by SketchUp after the user has selected a file
  # to import. This is where you do the real work of opening and
  # processing the file.
  #
  # @param [String] filename
  # @param [Boolean] show_summary
  #
  # @return [integer]
  def load_file(filename, show_summary)
    unless File.exist?(filename)
      Sketchup::Importer::ImportFileNotFound
    end
    base_path = File.dirname(filename)
    model = Sketchup.active_model
    options = get_options
    start_time = Time.now
    model.start_operation('Import OBJ', true)
    # The base group containing all the imported entities.
    group = model.active_entities.add_group
    group.name = File.basename(filename)
    context = Context.new
    context.filename = filename
    context.options = options
    context.root_entities = group.entities
    context.parent_entities = context.root_entities
    # The current Sketchup::Entities collection new entities should be added to.
    context.entities = context.root_entities
    # Material manager for the OBJ file being parsed.
    context.materials = MtlParser.new(model, base_path)
    # The current material which should be applied to geometry.
    context.material = nil
    # List of vertices defined for the OBJ file.
    # OBJ files uses 1-based indicies.
    context.vertex_cache = VertexCache.new
    context.vertex_cache.index_base = 1
    # A hash with smoothing group numbers mapping to the faces within the same
    # smoothing group.
    context.smoothing_groups = {}
    # The current smoothing group new faces should be added to unless its Nil.
    context.smoothing_group = nil
    # Statistics over the imported OBJ data.
    @stats = Statistics.new
    Sketchup.status_text = 'Importing OBJ file...'
    # @see http://paulbourke.net/dataformats/obj/
    # @see http://www.martinreddy.net/gfx/3d/OBJ.spec
    context.custom_encodings = nil
    context.encoding = 'UTF-8'
    attempts = 0
    begin
    File.open(filename, "r:#{context.encoding}:UTF-8") { |file|
      puts "Reading file. External encoding: #{file.external_encoding}"
      while (!file.eof?)
        context = parse(file, context)
      end
    }
    rescue ArgumentError, ObjEncodingError, EncodingError => error
      if error.is_a?(ArgumentError) && !error.message.include?('invalid byte sequence')
        raise
      end
      # TODO: Log errors. (Allow user to access?)
      puts error.backtrace.first
      context.custom_encodings ||= Encoding.name_list
      raise if context.custom_encodings.empty?
      context.encoding = context.custom_encodings.pop
      puts "Failed to read file. Retrying with encoding: #{context.encoding}"
      attempts += 1
      raise 'MAX ATTEMPTS' if attempts > Encoding.list.size
      retry
    end
    apply_smoothing_groups(context.smoothing_groups)
    model.commit_operation
    Sketchup.status_text = ''
    elapsed_time = Time.now - start_time
    formatted_time = "%0.4fs" % elapsed_time
    puts "Elapsed time: #{formatted_time}\n"
    # Display summary back to the user
    stats.materials = context.materials.used_materials.size
    stats.smoothing_groups = context.smoothing_groups.size
    if show_summary
      message = "OBJ Import Results\n"
      message << "\n"
      message << "Points: #{stats.points}\n"
      message << "Lines: #{stats.lines}\n"
      message << "Faces: #{stats.faces}\n"
      message << "Objects: #{stats.objects}\n"
      message << "Groups: #{stats.groups}\n"
      message << "Materials: #{context.materials.used_materials.size}\n"
      message << "Smoothing Groups: #{stats.smoothing_groups}\n"
      if stats.errors > 0
        message << "\n"
        message << "Errors: #{stats.errors}\n"
      end
      message << "\n"
      message << "Elapsed time: #{formatted_time}\n"
      # TODO: Add elapsed time.
      UI.messagebox(message, MB_MULTILINE)
    end
    Sketchup::Importer::ImportSuccess
  rescue Exception => exception
    model.abort_operation
    # Ensure the error is reported.
    ERROR_REPORTER.report(exception)
    # The importer interface have its own way to handle errors, so we don't
    # re-raise. Instead output to console.
    # TODO: Output to $STDERR?
    p exception
    puts exception.backtrace.join("\n")
    Sketchup::Importer::ImportFail
  end

  private

  # @param [Sketchup::Entities] entities
  def build(entities, &block)
    if defined?(Sketchup::EntitiesBuilder)
      entities.build(&block)
    else
      yield entities
    end
  end

  # @param [File] file
  # @param [Context] context
  def parse(file, context)
    build(context.entities) do |builder|
      while (!file.eof?) do
        line = file.readline

        # Filter out comments.
        next if line.start_with?('#')
        # Filter out empty lines.
        next if line.strip.empty?
        # Parse the line data and extract the line token.
        begin
          data = line.split(/\s+/)
        rescue ArgumentError => e
          #p line.bytes if e.message.include?('invalid byte sequence')
          if e.message.include?('invalid byte sequence')
            p line.encoding
            puts line
          end
          raise
        end
        token = data.shift
        case token
        when 'v'
          # Read the vertex data.
          raise 'invalid vertex data' if data.size < 3
          x, y, z = data.map { |n| convert_to_length(n, context.options[:units]) }
          point = Geom::Point3d.new(x, y, z)
          point.transform!(SWAP_YZ_TRANSFORM) if context.options[:swap_yz]
          context.vertex_cache.add_vertex(*point.to_a)
        when 'vt'
          # Read the vertex texture data.
          # Spec says default is 0.0, but that yield invalid data for SketchUp.
          u = data.x.to_f
          v = (data.y || 1.0).to_f
          w = (data.z || 1.0).to_f
          context.vertex_cache.add_uvw(u, v, w)
        when 'p'
          # Represent points as construction points.
          data.each { |n|
            v = n.to_i
            point = context.vertex_cache.get_vertex(v)
            entities.add_cpoint(point) unless @parse_only
            stats.points += 1
          }
        when 'l'
          # Create edges ("lines").
          points = data.map { |triplet|
            v = parse_triplet(triplet)[0]
            context.vertex_cache.get_vertex(v)
          }
          puts 'Line:'
          p points
          entities = builder.is_a?(Sketchup::Entities) ? builder : builder.entities
          entities.add_edges(points) unless @parse_only
          stats.edges += (points.size - 1)
          stats.lines += 1
        when 'f'
          # Crease polygon faces.
          points = []
          mapping = []
          data.each { |triplet|
            v, vt = parse_triplet(triplet)
            point = context.vertex_cache.get_vertex(v)
            if points.include?(point)
              # TODO: Message error back to user without raising error. Need to
              # continue reading file.
              puts 'Duplicate points found'
              puts "Line #{file.lineno}: #{line}"
              stats.errors += 1
              next
            end
            points << point
            if vt
              uvw = context.vertex_cache.get_uvw(vt)
              uvw.z = 1.0 if uvw.z = 0.0 # Account for some weird files.
              mapping << point
              mapping << TT::UVQ.normalize(uvw)
            end
          }
          unless @parse_only
            face = create_face(builder, points, context.material, mapping)
            if face.nil?
              puts "Line #{file.lineno}: #{line}"
              stats.errors += 1
              next
            end
            if context.smoothing_group
              context.smoothing_groups[context.smoothing_group] ||= []
              context.smoothing_groups[context.smoothing_group] << face
            end
          end
          stats.faces += 1
        when 'g'
          # Assuming that objects can contain groups.
          unless @parse_only
            group = context.parent_entities.add_group
            group.name = data[0] unless data[0].empty?
            context.entities = group.entities
            return context
          end
          stats.objects += 1
        when 'o'
          unless @parse_only
            group = context.root_entities.add_group
            group.name = data[0] unless data[0].empty?
            context.entities = group.entities
            context.parent_entities = context.entities
            return context
          end
          stats.groups += 1
        when 's'
          group_number = data[0] == 'off' ? nil : data[0].to_i
          group_number = nil if group_number == 0
          context.smoothing_group = group_number
        when 'mtllib'
          loaded = false
          data.each { |library|
            library_file = find_file(library, context.filename)
            loaded ||= context.materials.read(library_file)
          }
          if data.size > 1 && !loaded
            # Fall back to using the whole line as the filename. Version 0.8
            # exported MTL files with spaces if the OBJ file had spaces.
            result = line.match(/mtllib\s+(.+)/)
            next unless result
            library = result[1]
            library_file = find_file(library, context.filename)
            # TODO: Refactor puts to debug and/or logging.
            puts "falling back to trying: #{library_file}"
            loaded ||= context.materials.read(library_file)
          end
          raise ObjEncodingError if !loaded && context.custom_encodings
        when 'usemtl'
          # If we don't get a material from the MtlParser then it probably means
          # it wasn't able to find the materials file. In this case we try to
          # fall back to using currently selected material. UVLayout for
          # instance will generate new OBJ files without MTL files.
          # - Source: SketchUcation user Ithil
          # TODO(thomthom): Maybe expose this behaviour as a user option.
          # material = materials.get(data[0]) || model.materials.current
          context.material = context.materials.get(data[0])
          if context.material.nil?
            context.materials.load(data[0])
            context.material = context.materials.get(data[0])
          end
          if context.material.nil?
            # TODO: Message error back to user without raising error. Need to
            # continue reading file.
            puts "material not found: #{material_name}" if definition.nil?
            context.material = model.materials.current
          end
        else
          # Any other token is either unknown or not supported. No errors is
          # raised as the importer attempt to import what it can.
          # puts "Skipping token: #{token}" # TODO: Consider logging this.
          next
        end
      end
      puts "Import done!\n"
    rescue EOFError
      puts 'EOF...'
      break
    end
    context
  end

  Statistics = Struct.new(:points, :lines, :faces, :objects, :groups,
      :smoothing_groups, :materials, :edges, :errors) do
    def initialize(*args)
      super(*args)
      each_pair { |key, value|
        send("#{key.to_s}=", 0) if value.nil?
      }
    end
  end

  # @param [Hash{Integer => Array<Sketchup::Face, QuadFace>}] smoothing_groups
  #
  # @return [Nil]
  def apply_smoothing_groups(smoothing_groups)
    smoothing_groups.values.each { |faces|
      edge_refs = {}
      # Count how many times each edge is used by the faces in the smoothing
      # group.
      faces.each { |face|
        face.edges.each { |edge|
          edge_refs[edge] ||= 0
          edge_refs[edge] += 1
        }
      }
      # Any edge referencing two faces should be smooth. Less and it's at a
      # border, more and it's part of a fork.
      edge_refs.each { |edge, refs|
        next unless refs == 2
        edge.soft = true
        edge.smooth = true
      }
    }
    nil
  end

  # @param [Sketchup::EntitiesBuilder, Sketchup::Entities] builder
  # @param [Array<Geom::Point3d>] points
  # @param [Sketchup::Material, Nil] material
  # @param [Array<Geom::Point3d>] mapping
  #
  # @return [Sketchup::Face, QuadFace]
  def create_face(builder, points, material, mapping)
    if TT::Geom3d.planar_points?(points)
      face = builder.add_face(points)
      # Check face orientation. SketchUp might try to adjust the face to
      # a neighbouring face - and this isn't always ideal. For instance,
      # internal faces can easily affect exterior faces like this.
      face.reverse! if face_reversed?(points, face)
      if textured?(material) && (2..8).include?(mapping.size)
        # p ['mapping', material, mapping]
        begin
          face.position_material(material, mapping, true)
          face.position_material(material, mapping, false)
        rescue ArgumentError => error
          # TODO: Warn user about error. Log to error file.
          puts "Failed to map #{face} (#{face.entityID})"
          p mapping
          p error
          puts error.backtrace.join("\n")
          face.material = material
          face.back_material = material
        end
      else
        face.material = material
      end
    elsif points.size == 4
      entities = builder.is_a?(Sketchup::Entities) ? builder : builder.entities
      provider = EntitiesProvider.new([], entities, builder)
      face = provider.add_quad(points)
      # TODO: Check face orientation.
      if textured?(material) && !mapping.empty?
        vertices = sort_vertices(face.vertices, points)
        quad_mapping = {}
        vertices.each_with_index { |vertex, i|
          uvw = mapping[(i * 2) + 1]
          quad_mapping[vertex] = uvw
        }
        # p ['quad_mapping', material, quad_mapping]
        begin
          face.uv_set(material, quad_mapping, true)
          face.uv_set(material, quad_mapping, false)
        rescue ArgumentError => error
          # TODO: Warn user about error.
          puts "Failed to map quad #{face}"
          p mapping
          p error
          puts error.backtrace.join("\n")
          face.material = material
          face.back_material = material
        end
      else
        face.material = material
      end
    elsif points.size == 3
      # TODO: Throw custom errors that can be used for more detailed failure
      # messages.
      # TODO: TriangleTooSmall < CreateFaceError
      raise 'triangle is too small'
    elsif points.size < 3
      # TODO: NotEnoughUniquePoints < CreateFaceError
      raise 'polygon with less than three unique vertices'
    else
      # TODO: NgonNotPlanar < CreateFaceError
      raise 'cannot import n-gons which are not planar'
    end
    face
  rescue => error
    puts points.inspect.gsub(/Point3d/, 'Geom::Point3d.new')
    p error
    puts error.backtrace.join("\n")
    #raise
    nil
  end

  # @param [Array<Geom::Point3d>] points
  # @param [Sketchup::Face] face
  #
  # @return [Boolean]
  def face_reversed?(points, face)
    vertices = face.outer_loop.vertices
    start_point = points[0]
    start_vertex = vertices.find { |v| v.position == start_point }
    points[1] != vertices[1].position
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
    path = File.expand_path(File.dirname(relative_to))
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
    data.split('/').map { |n| n.empty? ? nil : n.to_i }
  end

  # @param [Array<Sketchup::Vertex>] vertices
  # @param [Array<Geom::Point3d>] order_by_points
  #
  # @return [Array<Sketchup::Vertex>]
  def sort_vertices(vertices, order_by_points)
    order_by_points.map { |point|
      vertex = vertices.find { |vertex| vertex.position == point }
      # TODO: Custom error. (?)
      raise 'unable to sort vertices' if vertex.nil?
      vertex
    }
  end

  # @return [Hash{Symbol => Object}]
  def default_options
    {
      :units   => UNIT_MODEL,
      :swap_yz => true
    }
  end

  # @return [Hash{Symbol => Object}]
  def get_options
    options = {}
    default_options.each { |key, default|
      value = Sketchup.read_default(IMPORTER_PREF_KEY, key.to_s, default)
      options[key] = value
    }
    options
  end

  # @param [Hash{Symbol => Object}] results
  #
  # @return [Nil]
  def process_options(results)
    return nil if results.nil? # In case Options were cancelled.
    # Save the options for next time.
    results.each { |key, value|
      Sketchup.write_default(IMPORTER_PREF_KEY, key.to_s, value)
    }
    nil
  end

end # class
end # module
