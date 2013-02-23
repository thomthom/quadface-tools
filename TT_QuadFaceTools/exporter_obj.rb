#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools

  module ExporterOBJ

    EXPORTER_VERSION = '0.1.0'.freeze

    POLYGON_MESH_POINTS     = 0b000
    POLYGON_MESH_UVQ_FRONT  = 0b001
    POLYGON_MESH_UVQ_BACK   = 0b010
    POLYGON_MESH_NORMALS    = 0b100
    POLYGON_MESH_EVERYTHING = 0b111

    # @since 0.8.0
    def self.export
      # Prompt for file to write to.
      model = Sketchup.active_model
      modelname = ( model.title.empty? ) ? 'Unsaved Model' : model.title
      filename = UI.savepanel( 'Export OBJ File', nil, "#{modelname}.obj" )
      return false unless filename

      File.open( filename, 'wb+' ) { |file|
        sketchup_name = ( Sketchup.is_pro? ) ? 'SketchUp Pro' : 'SketchUp'
        file.puts "# Exported with #{PLUGIN_NAME} (#{PLUGIN_VERSION})"
        file.puts "# #{sketchup_name} #{Sketchup.version}"
        file.puts "# Model name: #{modelname}"
        
        entities = model.active_entities
        tr = model.edit_transform 
        self.write_entities( file, modelname, entities, tr )
      }

      UI.messagebox("Exported to #{filename}")
    end

    # @since 0.8.0
    def self.write_entities(  file, name, native_entities,
                              transformation, vertex_index = 1 )
      entities = EntitiesProvider.new( native_entities )

      # Object grouping.
      file.puts ''
      file.puts "o #{name}"

      # Collect geometry data.
      vertices = TT::JSON.new # Ordered Hash
      faces = []
      instances = []
      for entity in entities
        case entity
        when Sketchup::Face, QuadFace
          # Collect outer loop of faces - ignoring inner holes.
          if entity.is_a?( QuadFace )
            outer_loop = entity.vertices
          else
            outer_loop = entity.outer_loop.vertices
          end
          # Build vertex index.
          for vertex in outer_loop
            next if vertices.key?( vertex )
            vertices[ vertex ] = vertex_index
            vertex_index += 1
          end
          # Build face index.
          faces << outer_loop.map { |vertex| vertices[ vertex ] }.join(' ')
        when Sketchup::Group, Sketchup::ComponentInstance
          # Write the ungrouped geometry first so it will appear as a separate
          # group. Cache all groups and components last.
          instances << entity
        end
      end

      # Write vertex index.
      file.puts ''
      for vertex, index in vertices
        global_position = vertex.position.transform( transformation )
        point = global_position.to_a.join(' ')
        file.puts "v #{point}"
      end

      # Write face definitions.
      file.puts ''
      for face in faces
        file.puts "f #{face}"
      end

      # Process sub-groups/components
      for instance in instances
        definition = TT::Instance.definition( instance )
        entities = definition.entities
        tr = transformation * instance.transformation
        name = self.instance_name( instance )
        vertex_index = self.write_entities( file, name, entities, tr, vertex_index )
      end

      vertex_index
    end

    # @since 0.8.0
    def self.instance_name( instance )
      definition = TT::Instance.definition( instance )
      if instance.name.empty? 
        instance_name = "Entity#{instance.entityID}"
      else
        instance_name = instance.name
      end
      name = "#{definition.name}-#{instance_name}"
      self.obj_compatible_name( name )
    end

    # @since 0.8.0
    def self.obj_compatible_name( string )
      string.gsub(/\s+/,'_') # Collapse and replace whitespace with _
    end

  end # module

end # module