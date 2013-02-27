#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools

  class ExporterOBJ

    EXPORTER_VERSION = '0.1.0'.freeze

    POLYGON_MESH_POINTS     = 0b000
    POLYGON_MESH_UVQ_FRONT  = 0b001
    POLYGON_MESH_UVQ_BACK   = 0b010
    POLYGON_MESH_NORMALS    = 0b100
    POLYGON_MESH_EVERYTHING = 0b111

    GROUP_BY_GROUPS  = 'g'.freeze
    GROUP_BY_OBJECTS = 'o'.freeze

    NO_MATERIAL = -1

    # @since 0.8.0
    def initialize
      @vertex_index = 1
      @smoothing_index = 1
      @materials = {}
      @last_material = NO_MATERIAL
    end

    # @since 0.8.0
    def prompt
      # Prompt for file to write to.
      model = Sketchup.active_model
      name = model_name( model )
      filename = UI.savepanel( 'Export OBJ File', nil, "#{name}.obj" )
      return false unless filename

      export( filename )

      UI.messagebox("Exported to #{filename}")
    end

    # @since 0.8.0
    def export( filename, group_type = GROUP_BY_OBJECTS )

      model = Sketchup.active_model
      name = model_name( model )

      Sketchup.status_text = 'Exporting OBJ file...'
      material_library = material_library_filename( filename )
      material_library_basename = File.basename( material_library )
      File.open( filename, 'wb+' ) { |file|
        sketchup_name = ( Sketchup.is_pro? ) ? 'SketchUp Pro' : 'SketchUp'
        file.puts "# Exported with #{PLUGIN_NAME} (#{PLUGIN_VERSION})"
        file.puts "# #{sketchup_name} #{Sketchup.version}"
        file.puts "# Model name: #{name}"
        file.puts "# Units: Inches"
        file.puts ''
        file.puts "mtllib #{material_library_basename}"
        
        tr = model.edit_transform
        entities = model.active_entities
        object_name = obj_compatible_name( name )
        write_entities( file, object_name, entities, tr, group_type )
      }
      Sketchup.status_text = 'Exporting material library for OBJ file...'
      write_material_library( material_library, model, name )
      Sketchup.status_text = 'Done!'

      true
    end

    private

    # @since 0.8.0
    def write_entities( file, name, native_entities, transformation, group_type )
      # Traverse the mesh and identify smoothing groups. Smoothing groups are
      # extracted by the Surface class and each surface must be processed
      # by the entity provider in order to extract the quads and other faces
      # within that surface group.
      entities = EntitiesProvider.new( native_entities )
      surfaces = Surface.get( native_entities, true )

      # Collect geometry data.
      vertices = TT::JSON.new # Ordered Hash
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
        write_entities( file, name, entities, tr, group_type )
      end

      vertices.size
    end

    # In order to optimize the OBJ file the surfaces are sorted by material.
    # It is only "surfaces" containing only one face that is sorted. The
    # surfaces with more than one face is sorted within their smoothing group.
    #
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

    # @since 0.8.0
    def write_surface( file, surface, transformation, vertices )
      # Collect vertices and faces.
      material_groups = {}
      new_vertices = []
      for face in surface
        # Build vertex index.
        outer_loop = get_face_loop( face )
        for vertex in outer_loop
          next if vertices.key?( vertex )
          new_vertices << vertex
          vertices[ vertex ] = @vertex_index
          @vertex_index += 1
        end
        # Build face definition.
        # (!) Sort by material.
        #faces << outer_loop.map { |vertex| vertices[ vertex ] }.join(' ')
        polygon = outer_loop.map { |vertex| vertices[ vertex ] }.join(' ')
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
        point = global_position.to_a.join(' ')
        file.puts "v #{point}"
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
    end

    # @since 0.8.0
    def write_material_library( filename, model, modelname )
      return false if @materials.empty?

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
          file.puts ''
          file.puts "newmtl #{name}"
          file.puts "Ka #{ambient_color}"
          file.puts "Kd #{diffuse_color}"
          file.puts "Ks #{specular_color}"
          file.puts "d #{opacity}" if opacity
        end
      }

      @materials.clear
      @last_material = NO_MATERIAL
      true
    end

    # @since 0.8.0
    def material_library_filename( obj_file_name )
      path = File.dirname( obj_file_name )
      basename = File.basename( obj_file_name, '.obj' )
      filename = File.join( path, "#{basename}.mtl" )
    end

    # @since 0.8.0
    def get_material_color( material, model )
      if material
        material.color
      else
        model.rendering_options['FaceFrontColor']
      end
    end

    # @since 0.8.0
    def format_material_color( color )
      rgb = color.to_a[0..2].map { |i| i / 255.0 }
      sprintf( '%.6f %.6f %.6f', *rgb )
    end

    # @since 0.8.0
    def format_material_opacity( material )
      opacity = ( material ) ? material.alpha : 1.0
      if opacity == 1
        nil
      else
        sprintf( '%.6f', opacity )
      end
    end

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

    # @since 0.8.0
    def get_obj_material_name( material, model )
      if material
        name = material.name
      else
        name = get_unique_material_name( model, 'FrontColor' )
      end
      obj_compatible_name( name )
    end

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

    # @since 0.8.0
    def obj_compatible_name( string )
      string.gsub(/\s+/,'_') # Collapse and replace whitespace with _
    end

    # @since 0.8.0
    def model_name( model )
      ( model.title.empty? ) ? 'Unsaved Model' : model.title
    end

    # @since 0.8.0
    def get_face_loop( face )
      if face.is_a?( QuadFace )
        face.vertices
      else
        face.outer_loop.vertices
      end
    end

  end # class

end # module