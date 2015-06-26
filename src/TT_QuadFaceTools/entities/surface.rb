#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/entities/entity'
require 'TT_QuadFaceTools/entities/quadface'

require 'TT_Lib2/edges'


module TT::Plugins::QuadFaceTools
class Surface < Entity

  attr_reader :faces

  # @param [Sketchup::Entity] face
  #
  # @return [Array<Sketchup::Entity,Surface>]
  def self.get(entities, sketchup_surface = false)
    cache = {}
    surfaces = []
    entities.map.each { |e|
      next if cache.include?(e)
      if e.is_a?(Sketchup::Face)
        surface = Surface.new(e, sketchup_surface)
        surface.faces.each { |face|
          cache[face] = face
        }
        surfaces << surface
      else
        surfaces << e
      end
    }
    surfaces
  end

  # @param [Sketchup::Face] face
  def initialize(face, sketchup_surface = false)
    @sketchup_surface = sketchup_surface
    @faces = get_surface(face)
  end

  # @return [Array<Sketchup::Edge>]
  def edges
    @faces.map { |face| border_edges(face.edges) }.flatten.uniq
  end

  # @return [Nil]
  def erase!
    if triangulated?
      edges = @faces.map { |face| face.edges }.flatten.uniq
      edges.reject! { |edge| !QuadFace.divider_props?(edge) }
      return nil if edges.empty?
      entities = edges[0].parent.entities
      entities.erase_entities(edges + @faces)
    else
      entities = @faces[0].parent.entities
      entities.erase_entities(@faces)
    end
    nil
  end

  # @return [Array<Array<Sketchup::Edge>>]
  def loops
    # (!)
    #   Returns nil when there is more than one loop.
    #   Todo: Find all loops.
    loop = TT::Edges.sort(edges)
    loop ? [loop] : nil
  end

  # @param [Sketchup::Edge] source_edge
  # @param [Integer] offset
  #
  # @return [Sketchup::Edge]
  def next_edge(source_edge, offset = 1)
    sorted_edges = outer_loop
    index = sorted_edges.index(source_edge)
    return nil if index.nil?
    new_index = (index + offset) % sorted_edges.size
    sorted_edges[new_index]
  end

  # @return [Array<Sketchup::Edge>]
  def outer_loop
    TT::Edges.sort(edges)
  end

  # @param [Sketchup::Edge] source_edge
  # @param [Integer] offset
  #
  # @return [Sketchup::Edge]
  def prev_edge(source_edge, offset = 1)
    sorted_edges = outer_loop
    index = sorted_edges.index(source_edge)
    return nil if index.nil?
    new_index = (index - offset) % sorted_edges.size
    sorted_edges[new_index]
  end

  # @return [Boolean]
  def triangulated?
    @faces.size > 1
  end

  # @return [Array<Sketchup::Vertex>]
  def vertices
    v = TT::Edges.sort_vertices(outer_loop)
    v.pop
    v
  end

  private

  # @param [Array<Sketchup::Edge>]
  #
  # @return [Array<Sketchup::Edge>]
  def border_edges(edges)
    if @sketchup_surface
      edges.reject { |edge| edge.soft? }
    else
      edges.reject { |edge| QuadFace.divider_props?(edge) }
    end
  end

  # @param [Sketchup::Face]
  #
  # @return [Array<Sketchup::Face>]
  def get_surface(face)
    surface = { face => face } # Use hash for speedy lookup
    stack = [face]
    until stack.empty?
      face = stack.shift
      edges = inner_edges(face.edges)
      edges.each { |edge|
        edge.faces.each { |edge_face|
          next if surface.key?(edge_face)
          stack << edge_face
          surface[edge_face] = edge_face
        }
      }
    end
    surface.keys
  end

  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  def inner_edges(edges)
    if @sketchup_surface
      edges.select { |edge| edge.soft? }
    else
      edges.select { |edge| QuadFace.divider_props?(edge) }
    end
  end

end # class
end # module
