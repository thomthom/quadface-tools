#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.6.0', 'TT QuadFace Tools')

#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  ID          = 'TT_QuadFaceTools'.freeze
  VERSION     = TT::Version.new(0,1,0).freeze
  PLUGIN_NAME = 'QuadFace Tools'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  #PATH        = File.join( PATH_ROOT, 'TT_Plugin' ).freeze
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( File.basename(__FILE__) )
    m = TT.menu( 'Tools' ).add_submenu( 'QuadFace Tools' )
    m.add_item( 'Inspect' )     { self.inspect_quad_faces }
    m.add_separator
    m.add_item( 'Ring' )        { self.select_rings }
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @since 0.1.0
  def self.inspect_quad_faces
    Sketchup.active_model.select_tool( QuadFaceInspector.new )
  end
  
  
  # @since 0.1.0
  def self.select_rings
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      entities.concat( find_edge_ring( entity ) )
    end
    # Select
    selection.clear
    selection.add( entities )
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.find_edge_ring( origin_edge )
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?( Sketchup::Edge )
    # Find initial connected QuadFaces
    return false unless ( 1..2 ).include?( origin_edge.faces.size )
    valid_faces = origin_edge.faces.select { |f| QuadFace.is?( f ) }
    quads = valid_faces.map { |face| QuadFace.new( face ) }
    # Find ring loop
    selected_faces = []
    selected_edges = [ origin_edge ]
    for quad in quads
      current_quad = quad
      current_edge = current_quad.opposite_edge( origin_edge )
      until current_edge.nil?
        selected_faces << current_quad
        selected_edges << current_edge
        # Look for more connected.
        current_quad = current_quad.next_face( current_edge )
        break unless current_quad # if nil
        current_edge = current_quad.opposite_edge( current_edge )
        # Stop if the entities has already been processed.
        break if selected_edges.include?( current_edge )
      end
    end
    selected_edges
  end
  
  
  # @since 0.1.0
  def self.triangulate_planar_quads
    # (!)
    # Native quad-faces are planar. If they are made non-planar SketchUp's
    # autofold feature kicks in and triangulates it. But the newly created
    # edge is not soft or smooth.
    #
    # To avoid native quads from becoming tris - this triangulate method will
    # ensure there is a soft and smooth edge.
  end
  
  
  # @since 0.1.0
  def self.transform
    # (!)
    # Transform a set of entities related to quadfaces - ensuring that native
    # quadfaces are triangulated correctly with a soft & smooth divider edge.
  end
  
  
  # @since 0.1.0
  def self.convert_connected_mesh_to_quads
    # (!)
    # Select a native quadface or two triangles. This will be the origin of the
    # mesh and from there the connected mesh will be attempted to be converted
    # into a quadface mesh.
  end
  
  
  # (!) Custom QuadFaceEdge class for smarter traversing of the QuadFace mesh.
  
  # @since 0.1.0
  class QuadFaceEdge
    
    # @param [Sketchup::Edge] edge
    #
    # @since 0.1.0
    def initialize( edge )
      raise ArgumentError, 'Invalid Edge' unless edge.is_a?( Sketchup::Edge )
      @edge = edge
      @faces = []
    end
    
    # @param [QuadFace] face
    #
    # @since 0.1.0
    def link_face( face )
      raise ArgumentError, 'Invalid QuadFace' unless face.is_a?( QuadFace )
      @faces << face unless @faces.include?( face )
    end
    
    # @param [QuadFace] face
    #
    # @since 0.1.0
    def unlink_face( face )
      raise ArgumentError, 'Invalid QuadFace' unless face.is_a?( QuadFace )
      @faces.delete( face )
    end
    
  end # class QuadFaceEdge
  
  
  # @since 0.1.0
  class QuadFace
    
    # @param [Sketchup::Entity] entitys
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.is?( entity )
      return false unless entity.is_a?( Sketchup::Face )
      face = entity
      return false unless (3..4).include?( face.vertices.size )
      soft_edges = face.edges.select { |e| e.soft? }
      if face.vertices.size == 3
        # Triangulated QuadFace
        return false unless soft_edges.size == 1
        dividing_edge = soft_edges[0]
        return false unless dividing_edge.faces.size == 2
        other_face = ( dividing_edge.faces - [face] ).first
        soft_edges = other_face.edges.select { |e| e.soft? }
        return false unless soft_edges.size == 1
      else # face.vertices.size == 4
        # Pure Quadface
        return false if soft_edges.size > 0
      end
      true
    end
    
    # @param [Sketchup::Face] face
    #
    # @since 0.1.0
    def initialize( face )
      unless valid_native_face?( face )
        raise ArgumentError, 'Invalid QuadFace'
      end
      @faces = [ face ]
      # Check if the quadface is triangualted.
      face2 = other_native_face( face )
      @faces << face2 if face2.is_a?( Sketchup::Face )
    end
    
    # @param [QuadFace] quadface
    #
    # @return [Sketchup::Edge,Nil]
    # @since 0.1.0
    def common_edge( quadface )
      unless quadface.is_a?( QuadFace )
        raise ArgumentError, 'Invalid QuadFace'
      end
      other_edges = quadface.edges
      match = edges.select { |edge| other_edges.include?( edge ) }
      return nil unless match
      match[0]
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.1.0
    def edges
      result = []
      for face in @faces
        result.concat( face.edges.select { |e| !e.soft? } )
      end
      result
    end
    
    # @return [Array<Sketchup::Face>]
    # @since 0.1.0
    def faces
      @faces.dup
    end
    
    # @param [Sketchup::Face] face
    #
    # @return [Boolean]
    # @since 0.1.0
    def include?( face )
      @faces.include?( face )
    end
    
    # @return [QuadFace,Nil]
    # @since 0.1.0
    def next_face( edge )
      return nil unless edge.faces.size == 2
      quadfaces = edge.faces.reject! { |face| @faces.include?( face ) }
      return nil if quadfaces.empty?
      return nil unless valid_native_face?( quadfaces[0] )
      QuadFace.new( quadfaces[0] )
    end
    
    # @return [Sketchup::Edge]
    # @since 0.1.0
    def opposite_edge( edge )
      edges = outer_loop()
      index = edges.index( edge )
      unless index
        raise ArgumentError, 'Edge not part of QuadFace loop.'
      end
      other_index = ( index + 2 ) % 4
      edges[ other_index ]
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.1.0
    def outer_loop
      TT::Edges.sort( edges )
    end
    
    private
    
    # @param [Sketchup::Face] face
    #
    # @return [Sketchup::Face]
    # @since 0.1.0
    def other_native_face( face )
      return nil unless face.vertices.size == 3
      soft_edges = face.edges.select { |e| e.soft? }
      return nil unless soft_edges.size == 1
      dividing_edge = soft_edges[0]
      return nil unless dividing_edge.faces.size == 2
      ( dividing_edge.faces - [face] ).first
    end
    
    # @param [Sketchup::Face] face
    #
    # @return [Boolean]
    # @since 0.1.0
    def valid_native_face?( face )
      return false unless face.is_a?( Sketchup::Face )
      return false unless (3..4).include?( face.vertices.size )
      # Check for bordering soft edges. Triangulated QuadFaces should have one
      # soft edge - where it joins the other triangle.
      # Native quads should have none.
      if face.vertices.size == 3
        # Triangulated QuadFace
        face2 = other_native_face( face )
        return false unless face2
      else # face.vertices.size == 4
        # Pure Quadface
        soft_edges = face.edges.select { |e| e.soft? }
        return false if soft_edges.size > 0
      end
      true
    end
  
  end # class Quadface
  
  
  # @since 0.1.0
  class QuadFaceInspector
    
    # @since 0.1.0
    def initialize
      model = Sketchup.active_model
      # Get workset.
      if model.selection.empty?
        entities = model.active_entities.to_a
      else
        entities = model.selection.to_a
      end
      # Find QuadFaces
      quads = entities.select { |e| QuadFace.is?( e ) }
      # Build draw cache
      edges = quads.map { |quad| quad.edges }
      edges.flatten!
      edges.uniq!
      edges.reject! { |e| e.soft? }
      @lines = edges.map { |e| [e.start.position, e.end.position] }
      @lines.flatten!
    end
    
    # @since 0.1.0
    def activate
      Sketchup.active_model.active_view.invalidate
    end
    
    # @since 0.1.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.1.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.1.0
    def draw( view )
      unless @lines.empty?
        view.line_stipple = ''
        view.line_width = 3
        view.drawing_color = 'Red'
        view.draw_lines( @lines )
      end
    end
    
  end # class QuadFaceInspector
  
  
  ### DEBUG ### ----------------------------------------------------------------  
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::QuadFaceTools.reload
  #
  # @param [Boolean] tt_lib
  #
  # @return [Integer]
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    #x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
    #  load file
    #}
    #x.length
  ensure
    $VERBOSE = original_verbose
  end
  
end # module

#-------------------------------------------------------------------------------

file_loaded( File.basename(__FILE__) )

#-------------------------------------------------------------------------------