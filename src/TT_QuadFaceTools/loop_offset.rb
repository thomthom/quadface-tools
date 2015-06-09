#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
class LoopOffset

  attr_reader :loop, :origin, :start_edge, :start_quad, :distance

  def initialize
    # The entities provider.
    @provider = EntitiesProvider.new

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

    # Cached array of points for the computed offset.
    @positions = nil
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
    @positions ||= calculate
  end

  def ready?
    (@loop && @origin && start_edge && @start_quad && @distance) ? true : false
  end

  # Inserts another loop into the mesh offset by the given distance.
  #
  # @return [Array<Edge>]
  def offset

  end

  private

  # Returns the set of points for the given offset.
  #
  # @return [Array<Geom::Point3d>]
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

    # TODO: This is just a dirty prototype. Clean up!
    i = 0
    loop = []
    stack = []
    stack << [pt1, edge1, @start_quad]
    stack << [pt2, edge2, @start_quad]
    until stack.empty?
      i += 1
      #puts "stack: #{i}"
      # @type point [Geom::Point3d]
      # @type edge [Sketchup::Edge]
      # @type quad [Quad]
      point, edge, quad = stack.pop
      loop << point

      next_quad = quad.next_quad(edge)
      #puts "> next_quad: #{next_quad}"

      next if next_quad.nil?
      edges = @loop & next_quad.edges
      next if edges.empty?
      raise if edges.size > 1
      loop_edge = edges[0]
      #puts "> loop_edge: #{loop_edge}"

      next_edge = next_quad.opposite_edge(edge)
      #puts "> next_edge: #{next_edge}"

      loop_line = [point, loop_edge.line[1]]
      next_point = Geom::closest_points(loop_line, next_edge.line)[1]

      stack << [next_point, next_edge, next_quad]

      break if stack.size == @loop.size

      if i >= @loop.size
        #puts "infinite loop! breaking out"
        #raise "infinite loop"
        break
      end
    end

    #[pt1, offset_origin, pt2]
    loop
  end

  def reset_cache
    @positions = nil
  end

end # class
end # module
