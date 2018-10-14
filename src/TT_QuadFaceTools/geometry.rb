#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_Lib2/edges'

module TT::Plugins::QuadFaceTools
module Geometry

  # @param [Array<Geom::Vector3d>]
  #
  # @return [Geom::Vector3d]
  def self.average_vector(vectors)
    vectors.inject(Geom::Vector3d.new) { |s, v| s + v }.normalize
  end

  # @param [Geom::Point3d] point1
  # @param [Geom::Point3d] point1
  # @param [Geom::Point3d] point2
  #
  # @return [Geom::Vector3d]
  def self.triangle_normal(point1, point2, point3)
    x_axis = point1.vector_to(point2)
    y_axis = point1.vector_to(point3)
    (x_axis * y_axis).normalize
  end

  # @param [Geom::Point3d] point
  # @param [Sketchup::Edge] edge
  #
  # @return [Geom::Point3d]
  def self.project_to_edge(point, edge)
    point_on_line = point.project_to_line(edge.line)
    if TT::Edge.point_on_edge?(point_on_line, edge)
      point_on_line
    else
      point1 = edge.start.position
      point2 = edge.end.position
      distance1 = point1.distance(point)
      distance2 = point2.distance(point)
      (distance1 < distance2) ? point1 : point2
    end
  end

  # @param [Geom::Point3d] point
  # @param [Array<Sketchup::Edge>] loop
  #
  # @return [Geom::Point3d]
  def self.project_to_loop(point, loop)
    stack = loop.dup
    point_on_loop = project_to_edge(point, stack.pop)
    distance_to_loop = point_on_loop.distance(point)
    stack.each { |edge|
      point_on_edge = project_to_edge(point, edge)
      distance_to_edge = point_on_edge.distance(point)
      if distance_to_edge < distance_to_loop
        point_on_loop = point_on_edge
        distance_to_loop = distance_to_edge
      end
    }
    point_on_loop
  end

end # module
end # module
