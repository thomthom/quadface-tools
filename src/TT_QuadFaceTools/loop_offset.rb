#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/face_splitter'


module TT::Plugins::QuadFaceTools
class LoopOffset

  attr_reader :loop, :origin, :start_edge, :start_quad, :distance

  # @param [EntitiesProvider] provider
  def initialize(provider)
    # The entities provider.
    @provider = provider

    # The source loop to be offset.
    @loop = nil

    # The source point on the source edge from where the offset is based.
    @origin = nil

    # The source edge in the loop from where the offset is based.
    @start_edge = nil

    # Quad indicating which side of the loop to offset.
    @start_quad = nil

    # The offset distance.
    @distance = nil

    # Result set of edge => point hash. Points might not be on the edge, but on
    # its line.
    @results = nil
  end

  # @param [Array<Sketchup::Edge>] value
  def loop=(value)
    @loop = value
    reset_cache
  end

  # @param [Geom::Point3d] value point on loop
  def origin=(value)
    @origin = value
    reset_cache
  end

  # @param [Sketchup::Edge] value
  def start_edge=(value)
    @start_edge = @provider.get(value)
    reset_cache
  end

  # @param [Sketchup::Edge] value
  def start_quad=(value)
    @start_quad = @provider.get(value)
    reset_cache
  end

  # @param [Length] value
  def distance=(value)
    @distance = value ? value.to_l : value
    reset_cache
  end

  # Returns the set of points for the given offset.
  #
  # @return [Array<Geom::Point3d>]
  def positions
    @results ||= calculate
    @results ? @results.positions : nil
  end

  def ready?
    (@loop && @origin && start_edge && @start_quad && @distance) ? true : false
  end

  # Inserts another loop into the mesh offset by the given distance.
  #
  # @return [Array<Edge>]
  def offset
    @results ||= calculate
    raise 'missing input parameters' if @results.nil?
    splitter = FaceSplitter.new(@provider)
    @results.each { |offset|
      splitter.add_split(offset.edge, offset.position)
    }
    new_loop = [] # TODO: Return split.
    splitter.split
    reset_cache
    new_loop
  end

  private

  class ResultSet < Array

    # Cached array of points for the computed offset.
    #
    # @return [Array<Geom::Point3d>]
    def positions
      @positions ||= map { |offset| offset.position }
    end

    # @return [Array<Sketchup::Edge>]
    def edges
      @edges ||= map { |offset| offset.edge }
    end

  end # class

  EdgeOffset = Struct.new(:edge, :position)

  # Returns the set of points for the given offset.
  #
  # @return [ResultSet<EdgeOffset>]
  def calculate
    return nil unless ready?
    # Find the native face connected to the start edge.
    face = @start_quad.faces.find { |face| face.edges.include?(@start_edge) }
    edge1 = @start_quad.next_edge(@start_edge)
    edge2 = @start_quad.opposite_edge(edge1)
    # Calculate the offset vector.
    face_points = face.vertices.map { |vertex| vertex.position }
    centroid = TT::Geom3d.average_point(face_points)
    point_on_start_edge = centroid.project_to_line(@start_edge.line)
    offset_vector = point_on_start_edge.vector_to(centroid)
    # Calculate the offset line.
    offset_origin = @origin.offset(offset_vector, @distance)
    line = [offset_origin, @start_edge.line[1]]
    # Calculate the offset points on the start quad's edges.
    pt1 = Geom::closest_points(line, edge1.line)[1]
    pt2 = Geom::closest_points(line, edge2.line)[1]
    # Traverse the loop to calculate the offset.
    stack = []
    stack << [pt1, edge1, @start_quad]
    # First in one direction, this will be enough if the loop is closed.
    results = traverse(stack)
    # If it's not a closed loop we also need to traverse in the other direction.
    if results.size < @loop.size
      stack.clear
      stack << [pt2, edge2, @start_quad]
      # We need to reverse the order of the first set in order to make the new
      # ones all appear in the same order.
      results.reverse!
      results.concat(traverse(stack))
    end
    # We now have a complete set of offset points.
    results
  end

  # @param [Array<Array(Geom::Point3d, Sketchup::Edge, Quad)>] stack
  #
  # @return [ResultSet<EdgeOffset>]
  def traverse(stack)
    results = ResultSet.new
    until stack.empty?
      point, edge, quad = stack.pop
      results << EdgeOffset.new(edge, point)
      # Traverse to the next neighboring quad.
      next_quad = quad.next_quad(edge)
      next if next_quad.nil?
      # Find the quad's shared edge with the loop - if any.
      edges = @loop & next_quad.edges
      next if edges.empty?
      raise if edges.size > 1
      loop_edge = edges[0]
      # Then we need the next edge that needs to be split.
      next_edge = next_quad.opposite_edge(edge)
      # Create a line parallel to the loop's edge - offset.
      loop_line = [point, loop_edge.line[1]]
      next_point = Geom::closest_points(loop_line, next_edge.line)[1]
      # Push the next item to the stack.
      stack << [next_point, next_edge, next_quad]
      # Make sure to break out when we've looped through a closed loop.
      if results.size > @loop.size
        break
      end
    end
    results
  end

  def reset_cache
    @results = nil
  end

end # class
end # module
