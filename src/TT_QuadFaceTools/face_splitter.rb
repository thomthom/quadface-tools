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

  # @param [Quad] quad
  # @param [MaterialData] material_data
  # @param [Boolean] front
  def apply_material(quad, material_data, front)
    return if material_data.nil?
    if material_data.mapping
      quad.uv_set(material_data.material, material_data.mapping, front)
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
        split_edges = quad.edges.select { |edge| split_map[edge] }
        next unless split_edges.size == 2
        # TODO: Verify the split points are on the edges.
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
    # Build a map of Sketchup::Edge => EdgeSplit pairs.
    map = {}
    face_split.edge_splits.each { |edge_split|
      map[edge_split.edge] = edge_split.position
    }
    # Determine the structure of the split in relationship to the vertex
    # indicies.
    v1, v2 = quad.vertices
    first_edge = v1.common_edge(v2)
    i = split_edges.include?(first_edge) ? 1 : 0
    vs = quad.vertices
    # Compute the positions for the new quads.
    points1 = [
      vs[i].position,
      vs[i + 1].position,
      map[vs[i + 1].common_edge(vs[i + 2])],
      map[vs[(i + 3) % 4].common_edge(vs[(i + 4) % 4])]
    ]
    points2 = [
      vs[i + 2].position,
      vs[(i + 3) % 4].position,
      map[vs[(i + 3) % 4].common_edge(vs[(i + 4) % 4])],
      map[vs[(i + 5) % 4].common_edge(vs[(i + 6) % 4])]
    ]
    # TODO: Compute the UV mapping of the new quads.
    # Build the data structures for the new quads.
    front_material_data = MaterialData.new(quad.material, nil)
    back_material_data = MaterialData.new(quad.back_material, nil)
    quad_data1 = QuadData.new(points1, front_material_data, back_material_data)
    quad_data2 = QuadData.new(points2, front_material_data, back_material_data)
    new_faces << quad_data1
    new_faces << quad_data2
    new_faces
  end

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
