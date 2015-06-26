#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/entities/quadface'
require 'TT_QuadFaceTools/entities/surface'

require 'TT_Lib2/edges'
require 'TT_Lib2/geom3d'


module TT::Plugins::QuadFaceTools
# Manages QuadFace entities in an collection of native SketchUp entities.
#
# The internal lookup table of Sketchup::Face => QuadFace is build progressively
# as the entities is accessed in order to maintain performance.
#
# In some usage scenarios one will want to use #analyse to pre-build the
# internal lookup table. For instance, if many native faces that makes up
# QuadFaces is added to the EntitiesProvider and one wants to get all quads
# from the collection using #quads - #analyse is needed to be called first.
#
# #each on the other hand will convert the native faces to Quads as it traverses
# the collection. When the collection is traversed the next time this conversion
# is not needed - therefore it's worth reusing the EntitiesProvider if possible.
class EntitiesProvider

  include Enumerable

  attr_reader(:model, :parent)

  # @param [Enumerable] entities
  # @param [Sketchup::Entities] parent
  def initialize(entities = [], parent = nil)
    # (?) Find a way to keep face => quad mapping separate from 'collection'
    #     Then make [] and get() the same.
    #     Make QuadFaces link to an EntitiesProvider so its methods return
    #     quads from the EntitiesProvider.

    # To quickly access entities by class this Hash is used.
    @types = {
        Sketchup::Edge => {},
        Sketchup::Face => {},
        QuadFace => {}
    } # Class => Sketchup::Entity,QuadFace
    # Map native faces to QuadFace.
    @faces_to_quads = {} # Sketchup::Face => QuadFace
    # For quick access and lookup, store everything in a Hash table.
    if entities.length > 0
      entities.each { |entity|
        cache_entity(entity)
      }
    end
    # Model and parent references
    @model = nil
    @parent = nil
    if parent.nil?
      if entities.length == 0
        @parent = Sketchup.active_model.active_entities
        @model = Sketchup.active_model
      else
        entity = entities[0]
        @parent = entity.parent.entities
        @model = entity.model
      end
    else
      @parent = parent
      @model = parent.model
    end
  end

  def initialize_copy(source)
    # .dup and .clone calls this.
    super
    @faces_to_quads = @faces_to_quads.dup
    @types = @types.dup
    @types.each { |klass, entities|
      @types[klass] = entities.dup
    }
  end

  # Define proxy object that pass the call through to the parent
  # Sketchup::Entities object.
  [
      :add_3d_text,
      :add_arc,
      :add_circle,
      :add_cline,
      :add_cpoint,
      :add_curve,
      :add_edges,
      :add_face,
      :add_faces_from_mesh,
      :add_group,
      :add_image,
      :add_instance,
      :add_line,
      :add_ngon,
      :add_text,
      :clear!,
      :erase_entities,
      :fill_from_mesh,
      :intersect_with,
      :transform_by_vectors,
      :transform_entities
 ].each { |method|
    define_method(method) { |*args| parent.send(method, *args) }
  }

  # Returns the entity from the EntitiesProvider. Any Sketchup::Face
  # entity that makes up a QuadFace will be returned as a QuadFace class.
  #
  # If the QuadFace exists in the EntitiesProvider collection it will be
  # reused.
  #
  # Any faces that forms a QuadFace not in the collection will return as
  # a QuadFace, but will *not* be added to the collection.
  #
  # This differs from #get which will add new QuadFace entities to the
  # collection.
  #
  # @overload [](entity)
  #   @param [Sketchup::Entity] entity
  # @overload [](entity1, entity2, ...)
  #   @param [Sketchup::Entity] entity1
  #   @param [Sketchup::Entity] entity2
  # @overload [](entities)
  #   @param [Enumerable<Sketchup::Entity>] entities
  #
  # @return [Sketchup::Entity,QuadFace]
  def [](*args)
    if args.size == 1
      entity = args[0]
      if entity.is_a?(Enumerable)
        entity.map { |e| get_entity(e) }
      else
        get_entity(entity)
      end
    else
      args.map { |entity| get_entity(entity) }
    end
  end

  # @overload add(entity)
  #   @param [Sketchup::Entity,QuadFace] entity
  # @overload add(entity1, entity2, ...)
  #   @param [Sketchup::Entity,QuadFace] entity1
  #   @param [Sketchup::Entity,QuadFace] entity2
  # @overload add(enumerable)
  #   @param [Enumerable] enumerable
  def add(*args)
    if args.length == 1 && args[0].is_a?(Enumerable)
      entities = args[0]
    else
      entities = args
    end
    entities.each { |entity|
      # (?) Verify parent?
      if entity.is_a?(QuadFace)
        # Special processing for QuadFaces.
        # If the quad's faces has already been added to the EntitiesProvider
        # then the already stored instance will be used.
        #
        # (?) Detect if any quads with two triangles share faces with another
        #     in case of invalid quads?
        if entity.faces.all? { |f| @faces_to_quads[f] }
          quad = @faces_to_quads[entity.faces[0]]
          cache_entity(quad)
        else
          cache_entity(entity)
        end
      else
        cache_entity(entity)
      end
    } # for
  end
  alias :<< :add

  # Add a QuadFace to the parent Sketchup::Entities collection.
  #
  # @overload add_quad(points)
  #   @param [Array<Geom::Point3d>] points
  # @overload add_quad(point1, point2, point3, point4)
  #   @param [Geom::Point3d] point1
  #   @param [Geom::Point3d] point2
  #   @param [Geom::Point3d] point3
  #   @param [Geom::Point3d] point4
  # @overload add_quad(edges)
  #   @param [Array<Sketchup::Edge>] edges
  # @overload add_quad(edge1, edge2, edge3, edge4)
  #   @param [Sketchup::Edge] edge1
  #   @param [Sketchup::Edge] edge2
  #   @param [Sketchup::Edge] edge3
  #   @param [Sketchup::Edge] edge4
  # @overload add_quad(curve)
  #   @param [Sketchup::Curve] curve
  def add_quad(*args)
    entities = parent
    # Array Argument
    if args.size == 1 && args.is_a?(Enumerable)
      args = args[0]
    end
    if args.size == 1 && args.is_a?(Sketchup::Curve)
      # Curve
      curve = args[0]
      points = curve.vertices.map { |v| v.position }
      if points.size != 4
        raise ArgumentError, 'Too many vertices in curve. Cannot create Quad.'
      end
    elsif args.size == 4 && args.all? { |a| a.is_a?(Sketchup::Edge) }
      # Edges
      loop = TT::Edges.sort(args)
      vertices = TT::Edges.sort_vertices(loop)
      points = vertices.map { |v| v.position }
    elsif args.size == 4 && args.all? { |a| a.is_a?(Geom::Point3d) }
      # Points
      points = args
    elsif args.size == 3 && args.all? { |a| a.is_a?(Geom::Point3d) }
      # Triangle
      return parent.add_face(args)
    else
      raise(ArgumentError, 'Invalid arguments. Cannot create Quad.')
    end
    # Create triangulated Quad if the quad is not planar.
    if TT::Geom3d.planar_points?(points)
      face = entities.add_face(points)
      QuadFace.new(face)
    else
      face1 = entities.add_face(points[0], points[1], points[2])
      face2 = entities.add_face(points[0], points[2], points[3])
      edge = (face1.edges & face2.edges)[0]
      QuadFace.set_divider_props(edge)
      QuadFace.new(face1)
    end
  end

  def add_surface(points)
    entities = parent
    if TT::Geom3d.planar_points?(points)
      face = entities.add_face(points)
      Surface.new(face)
    else
      # Create a planar mesh to use for triangulation.
      plane = Geom.fit_plane_to_points(points)
      planar_points = points.map { |pt| pt.project_to_plane(plane) }
      tempgroup = entities.add_group
      tempface = tempgroup.entities.add_face(planar_points)
      mesh = tempface.mesh
      tempgroup.erase!
      # Extract trangles.
      indexes = {}
      planar_points.each_with_index { |pt, i|
        index = mesh.point_index(pt)
        indexes[index] = points[i]
      }
      # Rebuild with original points.
      triangles = []
      mesh.polygons.each { |triangle|
        triangle_points = triangle.map { |i| indexes[i.abs] }
        triangles << entities.add_face(triangle_points)
      }
      # Orient normals.
      stack = triangles.dup
      base_normal = stack.shift.normal
      until stack.empty?
        face = stack.shift
        if face.normal % base_normal < 0
          face.reverse!
        end
      end
      # Smooth inner edges.
      inner = []
      stack = triangles.dup
      until stack.empty?
        current = stack.shift
        stack.each { |face|
          edges = face.edges & current.edges
          inner.concat(edges)
        }
      end
      inner.uniq!
      inner.each { |edge|
        QuadFace.set_divider_props(edge)
      }
      # Return a Surface entity.
      Surface.new(triangles.first)
    end
  end

  def all
    @types.values.map { |hash| hash.keys }.flatten
  end
  alias :to_a :all
  alias :to_ary :to_a

  # Processes the given set of entities give to #new and builds the cache
  # with native entities and QuadFace entities.
  #
  def analyse
    all.each { |entity|
      if @faces_to_quads[entity].nil? && QuadFace.is?(entity)
        quad = QuadFace.new(entity)
        cache_entity(quad)
      else
        cache_entity(entity)
      end
    }
    nil
  end

  def clear
    @types = {
        Sketchup::Edge => {},
        Sketchup::Face => {},
        QuadFace => {}
    } # Class => Sketchup::Entity,QuadFace
    # Map native faces to QuadFace.
    @faces_to_quads = {}
    nil
  end

  # Returns all QuadFace entities from entity#faces.
  #
  # @param [#faces] entity
  def connected_quads(entity)
    quads = []
    entity.faces.each { |face|
      e = get_entity(face) # (?) Add to cache?
      quads << e if e.is_a?(QuadFace)
    }
    quads
  end

  # @overload convert_to_quad(native_quad)
  #   @param [Sketchup::Face] native_quad
  #
  # @overload convert_to_quad(triangle1, triangle2, edge)
  #   @param [Sketchup::Face] triangle1
  #   @param [Sketchup::Face] triangle2
  #   @param [Sketchup::Edge] edge Edge separating the two triangles.
  #
  # @return [QuadFace]
  def convert_to_quad(*args)
    if args.size == 1
      face = args[0]
      face.edges.each { |edge|
        if QuadFace.divider_props?(edge)
          QuadFace.set_border_props(edge)
        end
      }
      QuadFace.new(face)
    elsif args.size == 3
      # (?) Third edge argument required? Can be inferred by the two triangles.
      face1, face2, dividing_edge = args
      QuadFace.set_divider_props(dividing_edge)
      [face1, face2].each { |face|
        face.edges.each { |edge|
          next if edge == dividing_edge
          if QuadFace.divider_props?(edge)
            QuadFace.set_border_props(edge)
          end
        }
      }
      QuadFace.new(face1)
    else
      raise ArgumentError, 'Incorrect number of arguments.'
    end
  end

  # Traverses the given set of entities given to #new. Discovers and cache
  # QuadFaces on the fly.
  def each
    # Cache to ensure unprocessed quad's native faces doesn't return twice.
    skip = {}
    all.each { |entity|
      if entity.is_a?(Sketchup::Face)
        next if skip[entity]
        if (quad = @faces_to_quads[entity])
          # Existing Quad
          quad.faces.each { |face|
            skip[face] = face
          }
          yield(quad)
        elsif QuadFace.is?(entity)
          # Unprocessed Quad
          quad = QuadFace.new(entity)
          cache_entity(quad)
          quad.faces.each { |face|
            skip[face] = face
          }
          yield(quad)
        else
          # Native Face
          cache_entity(entity)
          yield(entity)
        end
      else
        # All other entities
        cache_entity(entity)
        yield(entity)
      end
    }
  end

  # Returns all the edges for the cached entities.
  #
  # Use #analyse prior to this when full set if required.
  #
  # @return [Array<Sketchup::Edge>]
  def edges
    @types[Sketchup::Edge].keys
  end

  # @return [Boolean]
  def empty?
    all.empty?
  end

  # Returns all cached faces and QuadFaces.
  #
  # Use #analyse prior to this when full set if required.
  #
  # @return [Array<Sketchup::Face,QuadFace>]
  def faces
    @types[QuadFace].keys + @types[Sketchup::Face].keys
  end

  # Selects a loop of edges. Loop can be grown in steps.
  #
  # Currently using the Blender method - with exception of edges with no faces.
  #
  #
  # Blender
  #
  # Blender 2.58a
  # editmesh_mods.c
  # Line 1854
  #
  # selects or deselects edges that:
  # - if edges has 2 faces:
  #   - has vertices with valence of 4
  #   - not shares face with previous edge
  # - if edge has 1 face:
  #   - has vertices with valence 4
  #   - not shares face with previous edge
  #   - but also only 1 face
  # - if edge no face:
  #   - has vertices with valence 2
  #
  #
  # In Maya, an edge loop has the following properties:
  # * The vertices that connect the edges must have a valency equal to four.
  #   Valency refers to the number of edges connected to a particular vertex.
  # * The criteria for connecting the sequence is that the next edge in the
  #   sequence is the (i + 2nd) edge of the shared vertex, determined in order
  #   from the current edge (i).
  # * The sequence of edges (loop) can form either an open or closed path on the
  #   polygonal mesh.
  # * The start and end edges need not have a valency equal to four.
  #
  # @see http://download.autodesk.com/global/docs/maya2012/en_us/index.html?url=files/Polygon_selection_and_creation_Select_an_edge_loop.htm,topicNumber=d28e121344
  #
  # @todo Optimize is possible. Method is very slow!
  #
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  def find_edge_loop(origin_edge, step = false)
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?(Sketchup::Edge)
    # Find initial connected faces
    face_count = origin_edge.faces.size
    return [] unless (1..2).include?(face_count)
    faces = EntitiesProvider.new
    faces << get(origin_edge.faces).map { |f| f.edges }.flatten
    # Find edge loop.
    step_limit = 0
    loop = {}
    stack = [origin_edge]
    i = 0
    until stack.empty?
      i+=1
      edge = stack.shift
      # Find connected edges
      next_vertices = []
      edge.vertices.each { |v|
        edges = v.edges.reject { |e| is_diagonal?(e) }
        next if edges.size > 4 # Stop at forks
        next if edges.any? { |e| loop.include?(e) }
        next_vertices << v
      }
      # Add current edge to loop stack.
      loop[edge] = edge
      # Pick next edges
      valid_edges = 0
      next_vertices.each { |vertex|
        vertex.edges.each { |e|
          next if e == edge
          next if is_diagonal?(e)
          next if faces.include?(e)
          next if loop.include?(e)
          next unless e.faces.size == face_count
          valid_edges += 1
          stack << e
          faces << get(e.faces).map { |f| f.edges }.flatten
        } # for e
      } # for vertex
      # Stop if the loop is step-grown.
      if step
        step_limit = valid_edges if edge == origin_edge
        break if loop.size > step_limit
      end
    end # until
    loop.keys
  end

  # @param [Sketchup::Edge] origin_edge
  # @param [Boolean] step
  #
  # @return [Array<Sketchup::Edge>]
  def find_edge_ring(origin_edge, step = false)
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?(Sketchup::Edge)
    # Find initial connected QuadFaces
    return [] unless (1..2).include?(origin_edge.faces.size)
    quads = connected_quads(origin_edge)
    # Find ring loop
    selected_faces = []
    selected_edges = [origin_edge]
    quads.each { |quad|
      current_quad = quad
      current_edge = current_quad.opposite_edge(origin_edge)
      until current_edge.nil?
        selected_faces << current_quad
        selected_edges << current_edge
        break if step
        # Look for more connected.
        current_quad = current_quad.next_face(current_edge)
        break unless current_quad # if nil
        current_edge = current_quad.opposite_edge(current_edge)
        # Stop if the entities has already been processed.
        break if selected_edges.include?(current_edge)
      end
    }
    selected_edges
  end

  # @param [QuadFace] quad1
  # @param [QuadFace] quad2
  # @param [Boolean] step
  #
  # @return [Array<QuadFace>]
  def find_face_loop(quad1, quad2, step = false)
    # Find initial entities.
    edge1 = quad1.common_edge(quad2)
    edge2 = quad1.opposite_edge(edge1)
    edge3 = quad2.opposite_edge(edge1)
    # Prepare the stack.
    stack = []
    stack << [quad1, edge2]
    stack << [quad2, edge3]
    loop = quad1.faces + quad2.faces
    # Keep track of the faces processed.
    processed = {}
    quad1.faces.each { |f| processed[f] = f }
    quad2.faces.each { |f| processed[f] = f }
    # Find next quads.
    until stack.empty?
      quad, edge = stack.shift
      next_quad = quad.next_face(edge)
      next unless next_quad
      next if next_quad.faces.any? { |face| processed[face] }
      loop.concat(next_quad.faces)
      next_quad.faces.each { |f| processed[f] = f }
      unless step
        next_edge = next_quad.opposite_edge(edge)
        stack << [next_quad, next_edge]
      end
    end
    loop
  end

  # @param [QuadFace] quad
  # @param [Sketchup::Edge] edge
  #
  # @return [Array<QuadFace>]
  def find_face_ring(quad, edge)
    entities = []
    quad2 = quad.next_quad(edge)
    entities.concat(find_face_loop(quad, quad2)) if quad2
    entities
  end

  # Returns the entity from the EntitiesProvider. Any Sketchup::Face
  # entity that makes up a QuadFace will be returned as a QuadFace class.
  #
  # If the QuadFace exists in the EntitiesProvider collection it will be
  # reused.
  #
  # Any faces that forms a QuadFace not in the collection will return as
  # a QuadFace and added to the collection.
  #
  # This differs from #[] which will not add new QuadFace entities to the
  # collection.
  #
  # @overload [](entity)
  #   @param [Sketchup::Entity] entity
  # @overload [](entity1, entity2, ...)
  #   @param [Sketchup::Entity] entity1
  #   @param [Sketchup::Entity] entity2
  # @overload [](entities)
  #   @param [Enumerable<Sketchup::Entity>] entities
  #
  # @return [Sketchup::Entity,QuadFace]
  def get(*args)
    if args.size == 1
      entity = args[0]
      if entity.is_a?(Enumerable)
        entity.map { |e| get_entity(e, true) }
      else
        get_entity(entity, true)
      end
    else
      args.map { |entity| get_entity(entity, true) }
    end
  end

  # Returns an array of all cached entities of the given class.
  #
  # Use #analyse prior to this when full set if required.
  #
  # @param [Class] klass
  #
  # @return [Array<Sketchup::Entity,QuadFace>]
  def get_by_type(klass)
    @types[klass] ||= {}
    @types[klass].keys
  end

  # @return [String]
  def include?(entity)
    if (entities = @types[entity.class])
      entities.include?(entity) ||
          @faces_to_quads.include?(entity)
    else
      @faces_to_quads.include?(entity)
    end
  end

  # @return [String]
  def inspect
    hex_id = TT.object_id_hex(self)
    "#<#{self.class.name}:#{hex_id}>"
  end

  # Returns a boolean indicating whether the edge is the diagonal of a
  # triangulated QuadFace.
  #
  # @param [Sketchup::Edge] edge
  #
  # @return [Boolean]
  def is_diagonal?(edge)
    return false unless edge.is_a?(Sketchup::Edge)
    return false unless QuadFace.divider_props?(edge)
    return false unless edge.faces.size == 2
    return false unless edge.faces.all? { |face| face.vertices.size == 3 }
    face1, face2 = edge.faces
    edges = (face1.edges | face2.edges) - [edge]
    edges.all? { |e| !QuadFace.divider_props?(e) }
  end

  # @return [Integer]
  def length
    all.length
  end
  alias :size :length

  # Returns all cached native entities.
  #
  # Use #analyse prior to this when full set is required.
  #
  # @return [Array<Sketchup::Face>]
  def native_entities
    entities = []
    @types.each { |type, type_entities|
      if type == QuadFace
        entities.concat(type_entities.keys.map { |quad| quad.faces })
      else
        entities.concat(type_entities.keys)
      end
    }
    entities
  end
  # Returns all native faces for the cached entities.
  #
  # Use #analyse prior to this when full set if required.
  #
  # @return [Array<Sketchup::Face>]
  def native_faces
    @faces_to_quads.keys + @types[Sketchup::Face].keys
  end

  # Returns all cached QuadFaces.
  #
  # Use #analyse prior to this when full set if required.
  #
  # @return [Array<QuadFace>]
  def quads
    @types[QuadFace].keys
  end

  # Returns all the native faces for the cached QuadFaces.
  #
  # Use #analyse prior to this when full set if required.
  #
  # @return [Array<QuadFace>]
  def quad_faces
    @faces_to_quads.keys
  end

  private

  # @param [Sketchup::Entity] entity
  #
  # @return [Sketchup::Entity]
  def cache_entity(entity)
    entity_class = entity.class
    # Add to Type cache
    @types[entity_class] ||= {}
    @types[entity_class][entity] = entity
    # Add to Face => QuadFace mapping
    if entity.is_a?(QuadFace)
      entity.faces.each { |face|
        @faces_to_quads[face] = entity
        @types[Sketchup::Face].delete(face)
      }
    end
    entity
  end

  # @param [Sketchup::Entity] entity
  # @param [Boolean] add_to_cache
  #
  # @return [Sketchup::Entity,QuadFace]
  def get_entity(entity, add_to_cache = false)
    quad = @faces_to_quads[entity]
    if quad
      quad
    elsif QuadFace.is?(entity)
      quad = QuadFace.new(entity)
      if add_to_cache && @types[Sketchup::Face][entity].nil?
        cache_entity(quad)
      end
      quad
    else
      entity
    end
  end

end # class
end # module
