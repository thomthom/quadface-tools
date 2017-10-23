#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
class VertexCache

  # @return [Integer]
  attr_accessor :index_base

  def initialize
    @vertices = []
    @texture_data = []
    @index_base = 1
  end

  # @param [Numeric] x
  # @param [Numeric] y
  # @param [Numeric] z
  #
  # @return [Nil]
  def add_vertex(x, y, z)
    @vertices << Geom::Point3d.new(x, y, z)
    nil
  end

  # @param [Numeric] u
  # @param [Numeric] v
  # @param [Numeric] w
  #
  # @return [Nil]
  def add_uvw(u, v, w)
    @texture_data << Geom::Point3d.new(u, v, w)
    nil
  end

  # @param [Integer] index
  #
  # @return [Geom::Point3d]
  def get_vertex(index)
    i = get_index(index, @vertices)
    if i < 0 || i >= @vertices.size
      raise IndexError, "invalid vertex index: #{index} (#{i})"
    end
    @vertices[i]
  end

  # @param [Integer] index
  #
  # @return [Geom::Point3d]
  def get_uvw(index)
    i = get_index(index, @texture_data)
    if i < 0 || i >= @texture_data.size
      raise IndexError, "invalid vertex texture index: #{index} (#{i})"
    end
    @texture_data[i]
  end

  private

  # @param [Integer] index
  # @param [Enumerable] collection
  #
  # @return [Integer]
  def get_index(index, collection)
    unless index.is_a?(Integer)
      raise TypeError, "expected Integer, not #{index.class}"
    end
    index < 0 ? collection.size + index : index - @index_base
  end

end # class
end # module
