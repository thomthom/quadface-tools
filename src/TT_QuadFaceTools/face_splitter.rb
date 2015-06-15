#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/entities'


module TT::Plugins::QuadFaceTools
class FaceSplitter

  EdgeSplit = Struct.new(:edge, :position)
  FaceSplit = Struct.new(:face, :edge_splits)
  MaterialData = Struct.new(:material, :mapping)
  UVPair = Struct.new(:position, :uv)
  QuadData = Struct.new(:positions, :front, :back)

  # @param [EntitiesProvider] provider
  def initialize(provider)
    @provider = provider
    @edge_splits = []
    # Cached hash map of Sketchup::Edge => Geom::Position for @edge_splits.
    @split_map = nil
  end

  # @param [Sketchup::Edge] edge
  # @param [Geom::Position] position
  #
  # @return [Nil]
  def add_split(edge, position)
    @edge_splits << EdgeSplit.new(edge, position)
    nil
  end

  # @return [Boolean]
  def split
    return false if @edge_splits.empty?
    face_splits = compute_face_splits(@edge_splits)
    return false if face_splits.empty?
    # Compute new faces.
    new_faces = []
    existing_faces = []
    face_splits.each { |face_split|
      faces = compute_new_faces(face_split)
      unless faces.empty?
        new_faces.concat(faces)
        existing_faces.concat(face_split.face.faces)
      end
    }
    # Erase old faces that will be replaced by new ones.
    @provider.erase_entities(existing_faces)
    # Generate the new faces.
    new_faces.each { |face_data|
      quad = @provider.add_quad(face_data.positions)
      apply_material(quad, face_data.front, true)
      apply_material(quad, face_data.back, false)
    }
    new_faces.size > 0
  end

  private

  # @param [QuadFace] quad
  # @param [MaterialData] material_data
  # @param [Boolean] front
  def apply_material(quad, material_data, front)
    return if material_data.nil?
    if material_data.mapping
      # Verify that quad.vertices return the same order they where created.
      vertices = quad.vertices
      sorted_vertices = material_data.mapping.map { |pair|
        vertex = vertices.find { |vertex| vertex.position == pair.position }
        raise 'failed to sort vertices' if vertex.nil?
        vertex
      }
      # Apply the mapping to the quad.
      uvs = material_data.mapping.map { |pair| pair.uv }
      mapping = {}
      sorted_vertices.each_with_index { |vertex, i|
        mapping[vertex] = uvs[i]
      }
      quad.uv_set(material_data.material, mapping, front)
    else
      if front
        quad.material = material_data.material
      else
        quad.back_material = material_data.material
      end
    end
    nil
  end

  # @param [Array<EdgeSplits>]
  #
  # @return [Array<FaceSplits>]
  def compute_face_splits(edge_splits)
    face_splits = []
    processed = {}
    edge_splits.each { |split|
      quads = @provider.get(split.edge.faces).grep(QuadFace).select { |quad|
        !processed.key?(quad)
      }
      quads.each { |quad|
        processed[quad] = true
        split_edges = quad.edges.select { |edge|
          split = split_map[edge]
          split && TT::Edge.point_on_edge?(split.position, split.edge)
        }
        next unless split_edges.size == 2
        splits = split_edges.map { |edge| split_map[edge] }
        face_splits << FaceSplit.new(quad, splits)
      }
    }
    face_splits
  end

  # @param [FaceSplit] face_split
  #
  # @return [Array<QuadData>]
  def compute_new_faces(face_split)
    new_faces = []
    quad = face_split.face
    # Get the two edges that should be split.
    split_edges = face_split.edge_splits.map { |edge_split| edge_split.edge }
    # Determine the structure of the split in relationship to the vertex
    # indicies.
    v1, v2 = quad.vertices
    first_edge = v1.common_edge(v2)
    i = split_edges.include?(first_edge) ? 1 : 0
    vs = quad.vertices
    # Compute the positions for the new quads.
    [0, 2].each { |j|
      source = [
        vs[i + j],
        vs[(i + j + 1) % 4],
        vs[(i + j + 1) % 4].common_edge(vs[(i + j + 2) % 4]),
        vs[(i + j + 3) % 4].common_edge(vs[(i + j + 4) % 4])
      ]
      # Compute the positions for the new quads.
      points = source_points(source)
      # Build the data structures for the new quads.
      quad_data = QuadData.new(points)
      quad_data.front = MaterialData.new(quad.material)
      quad_data.front.mapping = uv_mapping(quad, source, true)
      quad_data.back = MaterialData.new(quad.back_material)
      quad_data.back.mapping = uv_mapping(quad, source, false)
      # Push to the result list.
      new_faces << quad_data
    }
    new_faces
  end

  # @param [QuadFace]
  # @param [Array<Sketchup::Vertex, Sketchup::Edge>] source
  # @param [Boolean] front
  #
  # @return [Array<UVPair>]
  def uv_mapping(quad, source, front)
    uvs = quad.uv_get(front)
    source.map { |entity|
      if entity.is_a?(Sketchup::Vertex)
        UVPair.new(entity.position, uvs[entity])
      elsif entity.is_a?(Sketchup::Edge)
        # Calculate the split point's weight in relationship to the edge's
        # start and end vertex.
        split = split_map[entity]
        weight = entity.start.position.distance(split.position) / entity.length
        # Now we can apply that to the UV data and get interpolated UV data
        # for new split point.
        uv1 = uvs[entity.start]
        uv2 = uvs[entity.end]
        uv = Geom.linear_combination(1.0 - weight, uv1, weight, uv2)
        UVPair.new(split.position, uv)
      else
        raise TypeError
      end
    }
  end

  # @param [Array<Sketchup::Vertex, Sketchup::Edge>] source
  #
  # @return [Array<Geom::Point3d>]
  def source_points(source)
    source.map { |entity|
      if entity.is_a?(Sketchup::Vertex)
        entity.position
      elsif entity.is_a?(Sketchup::Edge)
        split_map[entity].position
      else
        raise TypeError
      end
    }
  end

  # @return [Hash{Sketchup::Edge => EdgeSplit}]
  def split_map
    if @split_map.nil?
      @split_map = {}
      @edge_splits.each { |split|
        @split_map[split.edge] = split
      }
    end
    @split_map
  end

end # class
end # module
