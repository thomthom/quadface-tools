#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools

  # @see http://en.wikipedia.org/wiki/Wavefront_.obj_file
  # @see http://www.fileformat.info/format/wavefrontobj/egff.htm
  # @see http://www.martinreddy.net/gfx/3d/OBJ.spec
  # @see http://paulbourke.net/dataformats/obj/
  #
  # @since 0.8.0
  class ExporterOBJ

    EXPORTER_VERSION = '0.2.0'.freeze
    EXPORTER_PREF_KEY = "#{PLUGIN_ID}\\Exporter\\OBJ"

    # Geom::PolygonMesh
    POLYGON_MESH_POINTS     = 0b000
    POLYGON_MESH_UVQ_FRONT  = 0b001
    POLYGON_MESH_UVQ_BACK   = 0b010
    POLYGON_MESH_NORMALS    = 0b100
    POLYGON_MESH_EVERYTHING = 0b111

    # OBJ grouping alternatives.
    GROUP_BY_GROUPS  = 'g'.freeze
    GROUP_BY_OBJECTS = 'o'.freeze

    NO_MATERIAL = -1

    # Matches Sketchup.active_model.options['UnitsOptions']['LengthUnit']
    UNIT_MODEL       = -1 # Not a SketchUp value
    UNIT_INCHES      =  0
    UNIT_FEET        =  1
    UNIT_MILLIMETERS =  2
    UNIT_CENTIMETERS =  3
    UNIT_METERS      =  4
    UNIT_KILOMETERS  =  5 # Not a SketchUp value

    # Mirrors Sketchup::Importer constants
    EXPORT_SUCCESS  = 0
    EXPORT_FAIL     = 1
    EXPORT_CANCELED = 2

    # @since 0.8.0
    def initialize
      reset()
    end

    # @return [Integer]
    # @since 0.8.0
    def prompt
      # Prompt for options. (Hoping for Exporter API in SketchUp.)
      # (!) OSX Support
      last_options = load_last_options()
      options = option_dialog( last_options )
      return EXPORT_CANCELED unless options
      save_options( options )

      # Prompt for filename, ensuring .obj postfix.
      name = model_name( Sketchup.active_model )
      filename = UI.savepanel( 'Export OBJ File', nil, "#{name}.obj" )
      return EXPORT_CANCELED unless filename
      if filename.split('.').last != 'obj'
        filename = "#{filename}.obj"
      end

      # Export the model! :)
      if export( filename, options )
        UI.messagebox( "Exported to #{filename}" )
        EXPORT_SUCCESS
      else
        UI.messagebox( "Failed to export #{filename}" )
        EXPORT_FAIL
      end
    end

    # @param [String] filename
    # @param [Hash] options
    #
    # @return [Boolean]
    # @since 0.8.0
    def export( filename, options = {} )
      reset()
      @options.merge!( options )
      @scale = unit_ratio( @options[:units] )

      model = Sketchup.active_model
      name = model_name( model )
      filename = File.expand_path( filename )

      Sketchup.status_text = 'Exporting OBJ file...'
      mtl_filename = material_library_filename( filename )
      mtl_basename = File.basename( mtl_filename )
      object_name = obj_compatible_name( name )
      formatted_units = format_unit( @options[:units] )
      File.open( filename, 'wb+' ) { |file|
        sketchup_name = ( Sketchup.is_pro? ) ? 'SketchUp Pro' : 'SketchUp'
        file.puts "# Exported with #{PLUGIN_NAME} (#{PLUGIN_VERSION})"
        file.puts "# #{sketchup_name} #{Sketchup.version}"
        file.puts "# Model name: #{name}"
        file.puts "# Units: #{formatted_units}"
        file.puts ''
        file.puts "mtllib #{mtl_basename}"

        if @options[:group_type] == GROUP_BY_GROUPS
          file.puts ''
          file.puts "o #{object_name}"
        end

        file.puts ''
        file.puts "s off"
        
        if @options[:swap_yz]
          tr_axes = Geom::Transformation.axes(
            ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS
          )
          tr = tr_axes * model.edit_transform.inverse
        else
          tr = model.edit_transform.inverse
        end

        if @options[:selection]
          # (i) If partial surface or quad is selected, the whole surface or
          #     quad will be exported.
          entities = model.selection
        else
          entities = model.active_entities
        end
        write_entities( file, object_name, entities, tr )
      }
      Sketchup.status_text = 'Exporting material library for OBJ file...'
      write_material_library( mtl_filename, model, name )
      Sketchup.status_text = 'Done!'

      reset() # Clean up references for GC.
      true
    end

    # @return [Hash]
    # @since 0.8.0
    def load_last_options
      options = {}
      for key, default in @options
        value = Sketchup.read_default( EXPORTER_PREF_KEY, key.to_s, default )
        options[ key ] = value
      end
      options
    end

    private

    # @return [Hash]
    # @since 0.8.0
    def save_options( options )
      for key, value in options
        Sketchup.write_default( EXPORTER_PREF_KEY, key.to_s, value )
      end
    end

    # @return [Nil]
    # @since 0.8.0
    def reset
      @options = {
        :units        => UNIT_INCHES,
        :group_type   => GROUP_BY_OBJECTS,
        :swap_yz      => true,
        :texture_maps => true,
        :triangulate  => false,
        :selection    => false
      }

      @scale = 1

      @vertex_index = 1
      @uvs = TT::JSON.new # UV => Index

      @smoothing_index = 1

      @materials = {} # Material => OBJ_Name
      @last_material = NO_MATERIAL
      nil
    end

    # @param [File] file
    # @param [String] name
    # @param [Array<Sketchup::Entity>, Sketchup::Entities] native_entities
    # @param [Geom::Transformation] transformation
    #
    # @return [Integer]
    # @since 0.8.0
    def write_entities( file, name, native_entities, transformation )
      # Traverse the mesh and identify smoothing groups. Smoothing groups are
      # extracted by the Surface class and each surface must be processed
      # by the entity provider in order to extract the quads and other faces
      # within that surface group.
      entities = EntitiesProvider.new( native_entities )
      surfaces = Surface.get( native_entities, true )

      # Collect geometry data.
      vertices = TT::JSON.new # Vertex => Index (Needs to be here due to instances.)
      instances = []
      smoothing_groups = []
      for entity in surfaces
        case entity
        when Surface
          # Get faces and quads from surface.
          faces = entities.get( entity.faces ).uniq
          smoothing_groups << faces unless faces.empty?
        when Sketchup::Group, Sketchup::ComponentInstance
          # Write the ungrouped geometry first so it will appear as a separate
          # group. Cache all groups and components last.
          instances << entity
        end
      end

      # Write out the content of this context.
      unless smoothing_groups.empty?
        group_type = @options[ :group_type ]
        file.puts ''
        file.puts "#{group_type} #{name}"
        for surface in sort_surfaces_by_material( smoothing_groups )
          write_surface( file, surface, transformation, vertices )
        end
      end

      # Process sub-groups/components
      for instance in instances
        definition = TT::Instance.definition( instance )
        entities = definition.entities
        tr = transformation * instance.transformation
        name = instance_name( instance )
        write_entities( file, name, entities, tr )
      end

      surfaces.size
    end

    # In order to optimize the OBJ file the surfaces are sorted by material.
    # It is only "surfaces" containing only one face that is sorted. The
    # surfaces with more than one face is sorted within their smoothing group.
    #
    # @param [Array<Array<Sketchup::Face,QuadFace>>] surfaces
    #
    # @return [Array<Sketchup::Face,QuadFace>]
    # @since 0.8.0
    def sort_surfaces_by_material( surfaces )
      surfaces.sort { |a,b|
        if a.size == 1 && b.size == 1

          if a[0].material.nil?
            -1
          elsif b[0].material.nil?
            1
          else
            a[0].material <=> b[0].material
          end

        elsif a.size == 1
          -1
        elsif b.size == 1
          1
        else
          0
        end
      }
    end

    # @param [Sketchup::Face,QuadFace] face
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 0.8.0
    def get_uvs( face, outer_loop )
      if face.is_a?( QuadFace )
        mapping = face.uv_get( true )
      else
        mapping = {}
        uvh = face.get_UVHelper
        for vertex in outer_loop
          next if mapping[ vertex ]
          uvq = uvh.get_front_UVQ( vertex.position )
          mapping[ vertex ] = TT::UVQ.normalize( uvq )
        end
      end
      # Convert to arrays with only X and Y values. This avoids the issue of
      # hashes threating Point3d objects as all unique.
      uvs = {}
      for vertex, uv in mapping
        uvs[ vertex ] = uv.to_a[0..1]
      end
      uvs
    end

    # @param [Sketchup::Face,QuadFace] face
    #
    # @return [Boolean]
    # @since 0.8.0
    def textured?( face )
      face.material && face.material.texture ? true : false
    end

    # @param [File] file
    # @param [Array<Sketchup::Face,QuadFace>] surface
    # @param [Geom::Transformation] transformation
    #
    # @return [Integer]
    # @since 0.8.0
    def write_surface( file, surface, transformation, vertices )
      # Collect vertices and faces.
      material_groups = {}
      new_vertices = []
      new_uvs = []
      for face in surface
        # Build vertex index.
        outer_loop = get_face_loop( face )
        for vertex in outer_loop
          # Index vertex.
          unless vertices.key?( vertex )
            new_vertices << vertex
            vertices[ vertex ] = @vertex_index
            @vertex_index += 1
          end
        end
        if @options[:texture_maps] && textured?( face )
          # Build UV index
          face_uv_indexes = {}
          uvs = get_uvs( face, outer_loop )
          for vertex, uv in uvs
            unless index = @uvs[ uv ]
              new_uvs << uv
              index = @uvs.size + 1
              @uvs[ uv ] = index
            end
            face_uv_indexes[ vertex ] = index
          end
          # Build face definition.
          polygon = outer_loop.map { |vertex|
            vp = vertices[ vertex ]
            vt = face_uv_indexes[ vertex ]
            "#{vp}/#{vt}"
          }.join(' ')
        else
          # Build face definition.
          polygon = outer_loop.map { |vertex| vertices[ vertex ] }.join(' ')
        end
        material_groups[ face.material ] ||= []
        material_groups[ face.material ] << polygon
      end

      # Enable smoothing for each group only if it has more than one face.
      # Smoothing groups for a single face is redundant and just bloats the
      # file.
      if surface.size > 1
        file.puts ''
        file.puts "s #{@smoothing_index}"
      end

      # Write vertex index.
      file.puts '' if !new_vertices.empty?
      for vertex in new_vertices
        global_position = vertex.position.transform( transformation )
        point = global_position.to_a.map { |i| i * @scale }.join(' ')
        file.puts "v #{point}"
      end

      # Write UV index.
      if @options[:texture_maps]
        file.puts '' if !new_uvs.empty?
        for uvs in new_uvs
          coordinate = uvs.join(' ')
          file.puts "vt #{coordinate}"
        end
      end

      # Write face definitions.
      file.puts '' if !material_groups.empty? && !new_vertices.empty?
      for material, polygons in material_groups
        set_active_material( file, material )
        for polygon in polygons
          file.puts "f #{polygon}"
        end
      end

      # Turn off smoothing after each surface.
      if surface.size > 1
        file.puts ''
        file.puts "s off"
        @smoothing_index += 1
      end

      material_groups.size
    end

    # @param [String] filename
    # @param [Sketchup::Model] model
    # @param [String] modelname
    #
    # @return [Boolean]
    # @since 0.8.0
    def write_material_library( filename, model, modelname )
      return false if @materials.empty?

      if @options[:texture_maps]
        # Everything is wrapped in an operation which is aborted because
        # temporary groups has to be created in order to extract the images.
        model.start_operation( 'Extract OBJ Textures', true )
        tw = Sketchup.create_texture_writer
      end

      File.open( filename, 'wb+' ) { |file|
        sketchup_name = ( Sketchup.is_pro? ) ? 'SketchUp Pro' : 'SketchUp'
        file.puts "# Exported with #{PLUGIN_NAME} (#{PLUGIN_VERSION})"
        file.puts "# #{sketchup_name} #{Sketchup.version}"
        file.puts "# Model name: #{modelname}"
        
        for material, name in @materials
          color = get_material_color( material, model )
          ambient_color  = format_material_color( [0,0,0] )
          diffuse_color  = format_material_color( color )
          specular_color = sprintf( '%.6f %.6f %.6f', 0.33, 0.33, 0.33 ) # SU values
          opacity        = format_material_opacity( material )
          if @options[:texture_maps]
            texture      = extract_texture( model, tw, material, filename )
          end
          file.puts ''
          file.puts "newmtl #{name}"
          file.puts "Ka #{ambient_color}"
          file.puts "Kd #{diffuse_color}"
          file.puts "Ks #{specular_color}"
          file.puts "d #{opacity}" if opacity
          file.puts "map_Kd #{texture}" if @options[:texture_maps] && texture
        end
      }
      model.abort_operation if @options[:texture_maps]

      true
    rescue
      model.abort_operation if @options[:texture_maps]
      raise
    end

    # @param [Sketchup::Model] model
    # @param [Sketchup::TextureWriter] tw
    # @param [Sketchup::Material,Nil] material
    # @param [String] mtl_filename
    #
    # @return [String]
    # @since 0.8.0
    def extract_texture( model, tw, material, mtl_filename )
      return nil if material.nil?
      return nil if material.texture.nil?

      mtl_path = File.dirname( mtl_filename )
      texture_path_name = File.basename( mtl_filename, '.mtl' )
      texture_path = File.join( mtl_path, texture_path_name )

      basename = File.basename( material.texture.filename )
      texture_filetype = basename.split('.').last
      texture_basename = File.basename( basename, ".#{texture_filetype}" )
      texture_OBJ_name = obj_compatible_name( material.name )
      texture_filename = "#{texture_OBJ_name}.#{texture_filetype}"

      filename = File.join( texture_path, texture_filename )
      relative_filename = "#{texture_path_name}/#{texture_filename}"

      unless File.exist?( texture_path )
        Dir.mkdir( texture_path )
      end

      temp_group = model.entities.add_group
      temp_group.material = material
      tw.load( temp_group )
      unless tw.write( temp_group, filename ) == FILE_WRITE_OK
        puts "Failed to write #{material.display_name} to #{filename}"
      end

      relative_filename
    end

    # @param [String] obj_file_name
    #
    # @return [String]
    # @since 0.8.0
    def material_library_filename( obj_file_name )
      path = File.dirname( obj_file_name )
      basename = File.basename( obj_file_name, '.obj' )
      filename = File.join( path, "#{basename}.mtl" )
    end

    # @param [Sketchup::Material,Nil] material
    # @param [Sketchup::Model] model
    #
    # @return [Sketchup::Color]
    # @since 0.8.0
    def get_material_color( material, model )
      if material
        material.color
      else
        model.rendering_options['FaceFrontColor']
      end
    end

    # @param [Sketchup::Color] color
    #
    # @return [String]
    # @since 0.8.0
    def format_material_color( color )
      rgb = color.to_a[0..2].map { |i| i / 255.0 }
      sprintf( '%.6f %.6f %.6f', *rgb )
    end

    # @param [Sketchup::Material,Nil] material
    #
    # @return [String]
    # @since 0.8.0
    def format_material_opacity( material )
      opacity = ( material ) ? material.alpha : 1.0
      if opacity == 1
        nil
      else
        sprintf( '%.6f', opacity )
      end
    end

    # @param [File] file
    # @param [Sketchup::Material,Nil] material
    #
    # @return [String]
    # @since 0.8.0
    def set_active_material( file, material )
      unless @materials.key?( material )
        model = Sketchup.active_model
        @materials[ material ] = get_obj_material_name( material, model )
      end
      return nil if @last_material == material
      name = @materials[ material ]
      file.puts ''
      file.puts "usemtl #{name}"
      file.puts ''
      @last_material = material
      name
    end

    # @param [Sketchup::Material,Nil] material
    # @param [Sketchup::Model] model
    #
    # @return [String]
    # @since 0.8.0
    def get_obj_material_name( material, model )
      if material
        name = material.name
      else
        name = get_unique_material_name( model, 'FrontColor' )
      end
      obj_compatible_name( name )
    end

    # @param [Sketchup::Model] model
    # @param [String] string
    #
    # @return [String]
    # @since 0.8.0
    def get_unique_material_name( model, string )
      name = string
      index = 0
      while model.materials[ name ]
        name = "#{string}_#{index}"
        index += 1
      end
      name
    end

    # @param [Sketchup::Group,Sketchup::ComponentInstance,Sketchup::Image] instance
    #
    # @return [String]
    # @since 0.8.0
    def instance_name( instance )
      definition = TT::Instance.definition( instance )
      if instance.name.empty? 
        instance_name = "Entity#{instance.entityID}"
      else
        instance_name = instance.name
      end
      name = "#{definition.name}-#{instance_name}"
      obj_compatible_name( name )
    end

    # @param [String] string
    #
    # @return [String]
    # @since 0.8.0
    def obj_compatible_name( string )
      string.gsub( /\s+/, '_' ) # Collapse and replace whitespace with _
    end

    # @param [Sketchup::Model] model
    #
    # @return [String]
    # @since 0.8.0
    def model_name( model )
      ( model.title.empty? ) ? 'Unsaved Model' : model.title
    end

    # @param [Sketchup::Face,QuadFace] face
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 0.8.0
    def get_face_loop( face )
      if face.is_a?( QuadFace )
        face.vertices
      else
        face.outer_loop.vertices
      end
    end

    # @param [Hash] options
    #
    # @return [Hash]
    # @since 0.8.0
    def option_dialog( options )
      html_source = File.join( PATH_HTML, 'exporter.html' )

      window_options = {
        :dialog_title     => 'Export OBJ Options',
        :preferences_key  => false,
        :scrollable       => false,
        :resizable        => false,
        :left             => 500,
        :top              => 400,
        :width            => 330,
        :height           => 360
      }

      window = Window.new( window_options )
      window.set_size( window_options[:width], window_options[:height] )
      window.navigation_buttons_enabled = false

      window.add_action_callback( 'Window_Ready' ) { |dialog, params|
        dialog.update_value( 'lstInstances',         options[:group_type] )
        dialog.update_value( 'chkExportSelection',   options[:selection] )
        dialog.update_value( 'chkTriangulate',       options[:triangulate] )
        dialog.update_value( 'chkExportTextureMaps', options[:texture_maps] )
        dialog.update_value( 'chkSwapYZ',            options[:swap_yz] )
        dialog.update_value( 'lstUnits',             options[:units] )
      }

      results = nil
      window.add_action_callback( 'Event_Accept' ) { |dialog, params|
        # Get data from webdialog.
        results = {
          :group_type   => dialog.get_element_value('lstInstances'),
          :selection    => dialog.get_element_value('chkExportSelection'),
          :triangulate  => dialog.get_element_value('chkTriangulate'),
          :texture_maps => dialog.get_element_value('chkExportTextureMaps'),
          :swap_yz      => dialog.get_element_value('chkSwapYZ'),
          :units        => dialog.get_element_value('lstUnits')
        }
        # Convert to Ruby values.
        results[:selection]    = (results[:selection] == 'true')
        results[:triangulate]  = (results[:triangulate] == 'true')
        results[:texture_maps] = (results[:texture_maps] == 'true')
        results[:swap_yz]      = (results[:swap_yz] == 'true')
        results[:units]        = results[:units].to_i
        dialog.close
      }

      window.add_action_callback( 'Event_Cancel' ) { |dialog, params|
        dialog.close
      }

      window.set_file( html_source )
      window.show_modal
      results
    end

    # @param [Integer] unit
    #
    # @return [String]
    # @since 0.8.0
    def format_unit( unit )
      if unit == UNIT_MODEL
        unit = Sketchup.active_model.options['UnitsOptions']['LengthUnit']
      end
      unit_to_string( unit )
    end

    # @param [Integer] unit
    #
    # @return [String]
    # @since 0.8.0
    def unit_to_string( unit )
      case unit
      when UNIT_KILOMETERS
        'Kilometers'
      when UNIT_METERS
        'Meters'
      when UNIT_CENTIMETERS
        'Centimeters'
      when UNIT_MILLIMETERS
        'Millimeters'
      when UNIT_FEET
        'Feet'
      when UNIT_INCHES
        'Inches'
      when UNIT_MODEL
        'Model Units'
      else
        raise ArgumentError, 'Invalid unit type.'
      end
    end

    # @param [String] string
    #
    # @return [Integer]
    # @since 0.8.0
    def string_to_unit( string )
      case string
      when 'Kilometers'
        UNIT_KILOMETERS
      when 'Meters'
        UNIT_METERS
      when 'Centimeters'
        UNIT_CENTIMETERS
      when 'Millimeters'
        UNIT_MILLIMETERS
      when 'Feet'
        UNIT_FEET
      when 'Inches'
        UNIT_INCHES
      when 'Model Units'
        UNIT_MODEL
      else
        raise ArgumentError, 'Invalid unit string.'
      end
    end

    # @param [Integer] unit
    #
    # @return [Float]
    # @since 0.8.0
    def unit_ratio( unit )
      if unit == UNIT_MODEL
        unit = Sketchup.active_model.options['UnitsOptions']['LengthUnit']
      end
      case unit
      when UNIT_KILOMETERS
        0.0000254
      when UNIT_METERS
        0.0254
      when UNIT_CENTIMETERS
        2.54
      when UNIT_MILLIMETERS
        25.4
      when UNIT_FEET
        0.0833333333333333
      when UNIT_INCHES
        1
      else
        raise ArgumentError, 'Invalid unit type.'
      end
    end

  end # class

end # module