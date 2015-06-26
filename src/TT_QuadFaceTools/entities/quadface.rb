#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/entities/entity'

require 'TT_Lib2/edges'
require 'TT_Lib2/geom3d'
require 'TT_Lib2/uvq'


module TT::Plugins::QuadFaceTools
# Wrapper class for making handling of quad faces easier. Since a quad face
# might be triangulated, this class allows the possibly multiple native
# SketchUp entities to be treated as one object.
#
# A QuadFace is defined as:
# * A face with four vertices bound by non-soft edges.
# * Two triangular faces joined by a soft edge bound by non-soft edges.
class QuadFace < Entity

  # @param [Sketchup::Entity] entity
  #
  # @return [Boolean]
  def self.divider_props?(edge)
    return false unless edge.soft?
    return false unless edge.smooth?
    return false if edge.casts_shadows?
    true
  end

  # Evaluates if the entity is a face that forms part of a QuadFace.
  #
  # @see {QuadFace}
  #
  # @param [Sketchup::Entity] entity
  #
  # @return [Boolean]
  def self.dividing_edge?(edge)
    return false unless edge.is_a?(Sketchup::Edge)
    return false unless self.divider_props?(edge)
    return false unless edge.faces.size == 2
    return false unless edge.faces.all? { |face| face.vertices.size == 3 }
    edge.faces.all? { |face| self.is?(face) }
  end

  # Evaluates if the edge is part of a QuadFace.
  #
  # @param [Sketchup::Edge,Sketchup::Vertex] entity
  #
  # @return [Boolean]
  def self.entity_in_quad?(entity)
    entity.faces.any? { |face| self.is?(face) }
  end

  # @param [Array<Sketchup::Vertex>] vertices
  #
  # @return [QuadFace,Nil]
  def self.from_vertices(vertices)
    return nil unless vertices.size == 4
    vertex = vertices.first
    face = vertex.faces.find { |f|
      f.vertices.all? { |v| vertices.include?(v) }
    }
    return nil unless face
    return nil unless self.is?(face)
    quad = self.new(face)
    return nil unless quad.vertices.all? { |v| vertices.include?(v) }
    quad
  end

  # Evaluates if the entity is a face that forms part of a QuadFace.
  #
  # @see {QuadFace}
  #
  # @param [Sketchup::Entity] entity
  #
  # @return [Boolean]
  def self.is?(face)
    return false unless face.is_a?(Sketchup::Face)
    return false unless face.valid?
    vertex_count = face.vertices.size
    return false if vertex_count < 3
    return false if vertex_count > 4
    # Triangulated QuadFace needs special treatment.
    if vertex_count == 3
      edges = face.edges.select { |edge| self.divider_props?(edge) }
      return false unless edges.size == 1
      dividing_edge = edges[0]
      return false unless dividing_edge.faces.size == 2
      other_face = (dividing_edge.faces - [face]).first
      return false unless other_face.vertices.size == 3
      edges = other_face.edges.select { |edge| self.divider_props?(edge) }
      return false unless edges.size == 1
    end
    true
  end

  # @param [Sketchup::Entity] entity
  #
  # @return [Boolean]
  def self.valid_geometry?(*args)
    # (?) Unused?
    # Validate arguments
    unless (1..2).include?(args.size)
      raise ArgumentError, 'Must be one or two faces.'
    end
    unless args.all? { |e| e.is_a?(Sketchup::Face) }
      raise ArgumentError, 'Must be faces.'
    end
    # Validate geometric properties
    if args.size == 1
      # Native QuadFace
      face = args[0]
      return false unless face.vertices.size == 4
    else
      # Triangulated QuadFace
      face1, face2 = args
      return false unless face1.vertices.size == 3
      return false unless face2.vertices.size == 3
      return false unless face1.edges.any? { |e| face2.edges.include?(e) }
    end
    true
  end

  # @param [Sketchup::Edge] edge
  #
  # @return [Sketchup::Edge]
  def self.set_border_props(edge)
    if self.divider_props?(edge)
      edge.casts_shadows = true
    end
    edge
  end

  # @param [Sketchup::Edge] edge
  #
  # @return [Sketchup::Edge]
  def self.set_divider_props(edge)
    edge.soft = true
    edge.smooth = true
    edge.casts_shadows = false
    edge
  end

  # @param [Sketchup::Edge] edge
  #
  # @return [Sketchup::Edge]
  def self.smooth_edge(edge)
    if edge.faces.size > 1
      edge.soft = true
      edge.smooth = true
      edge.hidden = false
    end
    edge
  end

  # @param [Sketchup::Edge] edge
  #
  # @return [Sketchup::Edge]
  def self.unsmooth_edge(edge)
    edge.soft = false
    edge.smooth = false
    edge.hidden = false
    edge
  end

  # @note as of Version 0.6.0 this method does not validate the input entities.
  #   It is assumed they are all valid in order to maintain performance.
  #   Usually QuadFace.is? has been used to verify the entity anyway, so it
  #   would only mean double processing. In order to verify a created quad
  #   use #valid?.
  #
  # @overload initialize(quad_triangle)
  #   @param [Sketchup::Face] quad_triangle
  # @overload initialize(quad)
  #   @param [Sketchup::Face] quad
  # @overload initialize(triangle1, triangle2)
  #   @param [Sketchup::Face] triangle1
  #   @param [Sketchup::Face] triangle2
  # @overload initialize(edge_diagonal)
  #   @param [Sketchup::Edge] edge_diagonal
  def initialize(*args)
    if args.size == 1
      entity = args[0]
      if entity.is_a?(Sketchup::Edge)
        # Diagonal
        @faces = entity.faces
      elsif entity.is_a?(Sketchup::Face)
        if entity.vertices.size == 4
          # Native quad.
          @faces = [entity]
        else
          # Triangle - find the other triangle.
          edge = entity.edges.find { |e| QuadFace.divider_props?(e) }
          @faces = edge.faces
        end
      end
    elsif args.size == 2
      # Two triangles
      @faces = args
    else
      raise ArgumentError,
          "Invalid number of arguments. (#{args.size} out of 1..3)"
    end
  end

  # @return [Geom::Point3d]
  def centroid
    TT::Geom3d.average_point(positions)
  end

  # @param [#edges] entity
  #
  # @return [Sketchup::Edge,Nil]
  def common_edge(entity)
    unless entity.respond_to?(:edges)
      raise ArgumentError, 'Not a QuadFace or Sketchup::Face'
    end
    other_edges = entity.edges
    edges.find { |edge| other_edges.include?(edge) }
  end

  # Finds the quads connected to the quad's edges.
  #
  # @param [Array<Sketchup::Entity>] constraints
  #
  # @return [Array<QuadFace>]
  def connected_quads(constraints = nil)
    connected = []
    edges.each { |edge|
      edge.faces.each { |face|
        next if faces.include?(face)
        next unless QuadFace.is?(face)
        quad = QuadFace.new(face)
        if constraints
          if quad.faces.all? { |f| constraints.include?(f) }
            connected << quad
          end
        else
          connected << quad
        end
      }
    }
    connected
  end

  # @return [Boolean]
  def detriangulate!
    if @faces.size == 2 && planar?
      # Materials
      material_front = material
      material_back = back_material
      texture_on_front = material_front && material_front.texture
      texture_on_back  = material_back  && material_back.texture
      uv_front = nil
      uv_back = nil
      if texture_on_front || texture_on_back
        uv_front = uv_get(true)
        uv_back = uv_get(false)
      end
      # Erase divider
      divider.erase!
      @faces = @faces.select { |face| face.valid? }
      # Restore materials
      uv_set(material_front, uv_front) if texture_on_front
      uv_set(material_front, uv_back, false) if texture_on_back
      true
    else
      false
    end
  end

  # @return [Sketchup::Edge, Nil]
  def divider
    if @faces.size == 1
      nil
    else
      face1, face2 = @faces
      (face1.edges & face2.edges)[0]
    end
  end

  # @param [Sketchup::Edge]
  #
  # @return [Boolean]
  def edge_reversed?(edge)
    @faces.each { |face|
      next unless face.edges.include?(edge)
      return edge.reversed_in?(face)
    }
  end

  # Returns the edge positions in the same order as the outer loop of the quad.
  #
  # @param [Sketchup::Edge] edge
  #
  # @return [Array<Geom::Point3d>]
  def edge_positions(edge)
    edge_vertices(edge).map { |vertex| vertex.position }
  end

  # Returns the edge vertices in the same order as the outer loop of the quad.
  #
  # @param [Sketchup::Edge] edge
  #
  # @return [Array<Sketchup::Vertex>]
  def edge_vertices(edge)
    if edge_reversed?(edge)
      edge.vertices.reverse
    else
      edge.vertices
    end
  end

  # @return [Array<Sketchup::Edge>]
  def edges
    result = []
    if @faces.size == 1
      result = @faces[0].edges
    else
      @faces.each { |face|
        result.concat(face.edges.reject { |e| QuadFace.divider_props?(e) })
      }
    end
    result
  end

  def erase!
    if triangulated?
      divider.erase!
    else
      @faces[0].erase!
    end
    self
  end

  # @return [Boolean]
  def flip_edge
    if triangulated?
      verts = vertices
      pts = verts.map { |v| v.position }
      div = divider
      f1 = @faces[0]
      edges1 = f1.edges - [div]
      e1, e2 = edges1
      v1 = TT::Edges.common_vertex(e1, e2)
      i1 = verts.index(v1)
      # Materials
      material_front = material
      material_back = back_material
      texture_on_front = material_front && material_front.texture
      texture_on_back  = material_back  && material_back.texture
      uv_front = nil
      uv_back = nil
      if texture_on_front || texture_on_back
        uv_front = uv_get(true)
        uv_back = uv_get(false)
      end
      # Reorder points
      p1 = i1
      p2 = (p1 + 1) % 4
      p3 = (p2 + 1) % 4
      p4 = (p3 + 1) % 4
      pt1 = pts[p1]
      pt2 = pts[p2]
      pt3 = pts[p3]
      pt4 = pts[p4]
      # Recreate quadface
      entities = div.parent.entities
      div.erase!
      face1 = entities.add_face(pt1, pt2, pt3)
      face2 = entities.add_face(pt1, pt4, pt3)
      @faces = [face1, face2]
      div = (face1.edges & face2.edges)[0]
      QuadFace.set_divider_props(div)
      # Restore materials
      if texture_on_front
        uv_set(material_front, uv_front)
      else
        material = material_front
      end
      if texture_on_back
        uv_set(material_front, uv_back, false)
      else
        back_material = material_back
      end
      true
    else
      false
    end
  end

  # @return [Geom::PolygonMesh]
  def mesh
    if @faces.size == 1
      @faces[0].mesh
    else
      face1, face2 = @faces
      pm1 = face1.mesh
      pm2 = face2.mesh
      # Merge the polygon from face2 with face1.
      # (i) This assumes @faces contains two valid triangular faces.
      polygon = pm2.polygon_points_at(1)
      pm1.add_polygon(*polygon)
      pm1
    end
  end

  # @return [Sketchup::Edge, Nil]
  def next_edge(edge)
    loop = outer_loop
    index = loop.index(edge)
    return nil unless index
    next_index = (index + 1) % 4
    loop[next_index]
  end

  # @return [QuadFace, Nil]
  def next_face(edge)
    return nil unless edge.faces.size == 2
    quadfaces = edge.faces.reject! { |face| @faces.include?(face) }
    return nil if quadfaces.nil? || quadfaces.empty?
    return nil unless valid_native_face?(quadfaces[0])
    QuadFace.new(quadfaces[0])
  end
  alias :next_quad :next_face

  # @return [Sketchup::Edge]
  def opposite_edge(edge)
    edges = outer_loop
    index = edges.index( edge )
    unless index
      raise ArgumentError, 'Edge not part of QuadFace loop.'
    end
    other_index = (index + 2) % 4
    edges[other_index]
  end

  # @return [Array<Sketchup::Edge>]
  def outer_loop
    if @faces.size == 1
      @faces[0].outer_loop.edges
    else
      sorted = TT::Edges.sort(edges).uniq # .uniq due to a bug in TT_Lib 2.5
      # Ensure the edges run in the same direction as native outer loops.
      face = (@faces & sorted[0].faces)[0]
      sorted.reverse! if sorted[0].reversed_in?(face)
      sorted
    end
  end

  # @return [Boolean]
  def planar?
    @faces.size == 1 || TT::Geom3d.planar_points?(vertices)
  end

  # @return [Array<Geom::Point3d>]
  def positions
    vertices.map { |vertex| vertex.position }
  end

  # @return [Boolean]
  def triangulated?
    @faces.size > 1
  end

  # @return [Boolean]
  def triangulate!
    if @faces.size == 1
      # Materials
      material_front = material
      material_back = back_material
      texture_on_front = material_front && material_front.texture
      texture_on_back  = material_back  && material_back.texture
      uv_front = nil
      uv_back = nil
      if texture_on_front || texture_on_back
        uv_front = uv_get(true)
        uv_back = uv_get(false)
      end
      # (?) Validation required?
      face = @faces[0]
      entities = face.parent.entities
      mesh = face.mesh
      # Ensure a triangulated quad's edges doesn't have the properties of a
      # divider. If any of them has, then uncheck the hidden property.
      face.edges.each { |edge|
        QuadFace.set_border_props(edge)
      }
      # Find the splitting segment.
      polygon1 = mesh.polygon_at(1).map{ |i| i.abs }
      polygon2 = mesh.polygon_at(2).map{ |i| i.abs }
      split = polygon1 & polygon2
      # Add edge at split
      split.map! { |index| mesh.point_at(index) }
      edge = entities.add_line(*split)
      QuadFace.set_divider_props(edge)
      # Update references
      @faces = edge.faces
      # Restore materials
      uv_set(material_front, uv_front) if texture_on_front
      uv_set(material_front, uv_back, false) if texture_on_back
      true
    else
      false
    end
  end

  # @param [Boolean] front
  #
  # @return [Hash{Sketchup::Vertex => Geom::Point3d}]
  def uv_get( front = true )
    mapping = {}
    @faces.each { |face|
      uvh = face.get_UVHelper
      face.vertices.each { |vertex|
        next if mapping[vertex]
        if front
          uvq = uvh.get_front_UVQ(vertex.position)
        else
          uvq = uvh.get_back_UVQ(vertex.position)
        end
        mapping[vertex] = TT::UVQ.normalize(uvq)
      }
    }
    mapping
  end

  # @param [Sketchup::Material]
  # @param [Hash{Sketchup::Vertex => Geom::Point3d}] mapping
  # @param [Boolean] front
  #
  # @return [Boolean]
  def uv_set(new_material, mapping, front = true)
    unless new_material && new_material.texture
      material = new_material
      return false
    end
    @faces.each { |face|
      uvs = []
      face.vertices.each { |vertex|
        uvs << vertex.position
        uvs << mapping[vertex]
      }
      face.position_material(new_material, uvs, front)
    }
    true
  end

  # @return [Boolean]
  def valid?
    if @faces.size == 1
      face = @faces[0]
      face.valid? &&
          face.vertices.size == 4 &&
          edges.all? { |e| !QuadFace.divider_props?(e) }
    else
      @faces.size == 2 &&
          @faces.all? { |face|
            face.valid? &&
                face.vertices.size == 3
          } &&
          (edge = @faces[0].edges & @faces[1].edges).size == 1 &&
          QuadFace.divider_props?( edge[0] ) &&
          edge[0].faces.size == 2 &&
          edges.all? { |e| !QuadFace.divider_props?(e) }
    end
  end

  # @return [Array<Sketchup::Vertices>]
  def vertices
    # .uniq because .sort_vertices return the first vertex twice when the edges
    # form a loop.
    TT::Edges.sort_vertices(outer_loop).uniq
  end

  private

  # @param [Sketchup::Face] face
  #
  # @return [Sketchup::Face, Nil]
  def other_native_face(face)
    return nil unless face.vertices.size == 3
    edges = face.edges.select { |e| QuadFace.divider_props?(e) }
    return nil unless edges.size == 1
    dividing_edge = edges[0]
    return nil unless dividing_edge.faces.size == 2
    dividing_edge.faces.find { |f| f != face }
  end

  # TODO: This should return a bool consistently.
  # @param [Sketchup::Face] face
  #
  # @return [Boolean] for native quad
  # @return [Sketchup::Face, Nil, False] for triangulated quads
  def valid_native_face?(face)
    return false unless face.is_a?(Sketchup::Face)
    vertex_count = face.vertices.size
    return false if vertex_count < 3
    return false if vertex_count > 4
    # Check for bordering soft edges. Triangulated QuadFaces should have one
    # soft edge - where it joins the other triangle.
    # Native quads should have none.
    if vertex_count == 3
      edges = face.edges.select { |e| QuadFace.divider_props?(e) }
      return false unless edges.size == 1
      other_native_face(face)
    else
      true # Native Quad
    end
  end

end # class
end # module
