#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
class VertexCache

  attr_accessor :index_base

  def initialize
    @vertices = []
    @texture_data = []
    @index_base = 1
  end

  def add_vertex(x, y, z)
    @vertices << Geom::Point3d.new(x, y, z)
  end

  def add_uvw(u, v, w)
    @texture_data << Geom::Point3d.new(u, v, q)
  end

  def get_vertex(index)
    i = get_index(index)
    if i < 0 || i >= @vertices.size
      raise IndexError, 'invalid vertex index'
    end
    @vertices[i]
  end

  def get_uvw(index)
    i = get_index(index)
    if i < 0 || i >= @texture_data.size
      raise IndexError, 'invalid vertex texture index'
    end
    @texture_data[i]
  end

  private

  def get_index(index)
    index < 0 ? index : index - @index_base
  end

end # class
end # module
