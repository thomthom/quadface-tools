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

    # @since 0.8.0
    def initialize
      @vertex_index = 1
      @smoothing_index = 1
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

      File.open( filename, 'wb+' ) { |file|
        sketchup_name = ( Sketchup.is_pro? ) ? 'SketchUp Pro' : 'SketchUp'
        file.puts "# Exported with #{PLUGIN_NAME} (#{PLUGIN_VERSION})"
        file.puts "# #{sketchup_name} #{Sketchup.version}"
        file.puts "# Model name: #{name}"
        
        tr = model.edit_transform
        entities = model.active_entities
        object_name = obj_compatible_name( name )
        write_entities( file, object_name, entities, tr, group_type )
      }

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
        for surface in smoothing_groups
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

    # @since 0.8.0
    def write_surface( file, surface, transformation, vertices )
      # Collect vertices and faces.
      faces = []
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
        faces << outer_loop.map { |vertex| vertices[ vertex ] }.join(' ')
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
      file.puts '' if !faces.empty? && !new_vertices.empty?
      for face in faces
        file.puts "f #{face}"
      end

      # Turn off smoothing after each surface.
      if surface.size > 1
        file.puts ''
        file.puts "s off"
        @smoothing_index += 1
      end
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