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
  PATH        = File.join( PATH_ROOT, 'TT_QuadFaceTools' ).freeze
  PATH_ICONS  = File.join( PATH, 'Icons' ).freeze
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( File.basename(__FILE__) )
    # Commands
    cmd = UI::Command.new( 'Select' )   { self.select_quadface_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Select_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Select_24.png' )
    cmd.status_bar_text = 'Select Tool.'
    cmd.tooltip = 'Select'
    cmd_select = cmd
    
    cmd = UI::Command.new( 'Grow Selection' ) { self.selection_grow }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionGrow_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionGrow_24.png' )
    cmd.status_bar_text = 'Grow Selection.'
    cmd.tooltip = 'Grow Selection'
    cmd_selection_grow = cmd
    
    cmd = UI::Command.new( 'Shrink Selection' ) { self.selection_shrink }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionShrink_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionShrink_24.png' )
    cmd.status_bar_text = 'Shrink Selection.'
    cmd.tooltip = 'Shrink Selection'
    cmd_selection_shrink = cmd
    
    cmd = UI::Command.new( 'Ring' ) { self.select_rings }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectRing_24.png' )
    cmd.status_bar_text = 'Select Ring.'
    cmd.tooltip = 'Select Ring'
    cmd_select_ring = cmd
    
    cmd = UI::Command.new( 'Grow Ring' )  { self.select_rings( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowRing_24.png' )
    cmd.status_bar_text = 'Grow Ring.'
    cmd.tooltip = 'Grow Ring'
    cmd_grow_ring = cmd
    
    cmd = UI::Command.new( 'Shrink Ring' )  { self.select_rings( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkRing_24.png' )
    cmd.status_bar_text = 'Shrink Ring.'
    cmd.tooltip = 'Shrink Ring'
    cmd.set_validation_proc { MF_GRAYED }
    cmd_shrink_ring = cmd
    
    cmd = UI::Command.new( 'Loop' ) { self.select_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectLoop_24.png' )
    cmd.status_bar_text = 'Select Loop.'
    cmd.tooltip = 'Select Loop'
    cmd_select_loop = cmd
    
    cmd = UI::Command.new( 'Grow Loop' )  { self.select_loops( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowLoop_24.png' )
    cmd.status_bar_text = 'Grow Loop.'
    cmd.tooltip = 'Grow Loop'
    cmd_grow_loop = cmd
    
    cmd = UI::Command.new( 'Shrink Loop' )  { self.select_loops( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkLoop_24.png' )
    cmd.status_bar_text = 'Shrink Loop.'
    cmd.tooltip = 'Shrink Loop'
    cmd.set_validation_proc { MF_GRAYED }
    cmd_shrink_loop = cmd
    
    # Menus
    m = TT.menu( 'Tools' ).add_submenu( 'QuadFace Tools' )
    m.add_item( cmd_select )
    m.add_separator
    m.add_item( cmd_selection_grow )
    m.add_item( cmd_selection_shrink )
    m.add_separator
    m.add_item( cmd_select_ring )
    m.add_item( cmd_grow_ring )
    m.add_item( cmd_shrink_ring )
    m.add_separator
    m.add_item( cmd_select_loop )
    m.add_item( cmd_grow_loop )
    m.add_item( cmd_shrink_loop )
    
    # Context menu
    #UI.add_context_menu_handler { |context_menu|
    #  model = Sketchup.active_model
    #  selection = model.selection
    #  # ...
    #}
    
    # Toolbar
    toolbar = UI::Toolbar.new( PLUGIN_NAME )
    toolbar.add_item( cmd_select )
    toolbar.add_separator
    toolbar.add_item( cmd_selection_grow )
    toolbar.add_item( cmd_selection_shrink )
    toolbar.add_separator
    toolbar.add_item( cmd_select_ring )
    toolbar.add_item( cmd_grow_ring )
    toolbar.add_item( cmd_shrink_ring )
    toolbar.add_separator
    toolbar.add_item( cmd_select_loop )
    toolbar.add_item( cmd_grow_loop )
    toolbar.add_item( cmd_shrink_loop )
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @since 0.1.0
  def self.select_quadface_tool
    Sketchup.active_model.select_tool( SelectQuadFace.new )
  end
  
  
  # @since 0.1.0
  def self.select_rings( step = false )
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      entities.concat( find_edge_ring( entity, step ) )
    end
    # Select
    selection.clear
    selection.add( entities )
  end
  
  
  # @since 0.1.0
  def self.select_loops( step = false )
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      entities.concat( find_edge_loop( entity, step  ) )
    end
    # Select
    selection.clear
    selection.add( entities )
  end
  
  
  # @since 0.1.0
  def self.selection_grow
    selection = Sketchup.active_model.selection
    new_selection = []
    for entity in selection
      if entity.is_a?( Sketchup::Edge )
        for vertex in entity.vertices
          edges = vertex.edges.select { |e| !QuadFace.dividing_edge?( e ) }
          new_selection.concat( edges )
        end
      elsif entity.is_a?( Sketchup::Face )
        if QuadFace.is?( entity )
          face = QuadFace.new( entity )
        else
          face = entity
        end
        for edge in face.edges
          for f in edge.faces
            if QuadFace.is?( f )
              qf = QuadFace.new( f )
              new_selection.concat( qf.faces )
            else
              new_selection << f
            end
          end
        end # for edge in face.edges
      end # if entity.is_a?
    end # for entity
    # Update selection
    selection.add( new_selection )
  end
  
  
  # @since 0.1.0
  def self.selection_shrink
    selection = Sketchup.active_model.selection
    new_selection = []
    for entity in selection
      if entity.is_a?( Sketchup::Edge )
        unless entity.vertices.all? { |vertex|
          edges = vertex.edges.select { |e| !QuadFace.dividing_edge?( e ) }
          edges.all? { |edge| selection.include?( edge ) }
        }
          new_selection << entity
        end
      elsif entity.is_a?( Sketchup::Face )
        unless entity.edges.all? { |edge|
          edge.faces.all? { |face|
            if QuadFace.is?( face )
              qf = QuadFace.new( face )
              qf.faces.any? { |f| selection.include?( f ) }
            else
              selection.include?( face )
            end
          }
        }
          if QuadFace.is?( entity )
            qf = QuadFace.new( entity )
            new_selection.concat( qf.faces )
          else
            new_selection << entity
          end
        end
      end # if entity.is_a?
    end # for entity
    # Update selection
    selection.remove( new_selection )
  end
  
  
  # @since 0.1.0
  def self.process_entity( entity )
    if entity.is_a?( Sketchup::Face ) && QuadFace.is?( entity )
      entity = QuadFace.new( entity )
    end
    entity
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.find_edge_ring( origin_edge, step = false )
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
        break if step
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
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.find_edge_loop( origin_edge, step = false )
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?( Sketchup::Edge )
    # Find initial connected QuadFaces
    return false unless ( 1..2 ).include?( origin_edge.faces.size )
    quads = self.connected_quad_faces( origin_edge )
    # Find ring loop
    loop = []
    stack = [ origin_edge ]
    until stack.empty?
      edge = stack.shift
      # Find connected edges
      next_vertices = []
      for v in edge.vertices
        next if v.edges.any? { |e| loop.include?( e ) }
        next_vertices << v
      end
      # Add to loop
      loop << edge
      break if step && loop.size > 2 # (!) Incorrect unless it grows in both directions.
      # Get connected faces
      quads = self.connected_quad_faces( edge )
      # Pick next edges
      for vertex in next_vertices
        for e in vertex.edges
          next if e == edge
          next if e.soft?
          next if quads.any? { |q| q.edges.include?( e ) }
          next if loop.include?( e )
          next if self.connected_quad_faces( e ).empty?
          # (!) Bug! Branches where a loop meets missing faces.
          stack << e
        end # for e
      end # for vertex
    end # until
    loop
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.connected_quad_faces( edge )
    # Get connected faces
    valid_faces = edge.faces.select { |f| QuadFace.is?( f ) }
    quads = valid_faces.map { |face| QuadFace.new( face ) }
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
  
  
  # Wrapper class for making handling of quad faces easier. Since a quad face
  # might be triangulated, this class allows the possibly multiple native
  # SketchUp entities to be treated as one object.
  #
  # A QuadFace is defined as:
  # * A face with four vertices bound by non-soft edges.
  # * Two triangular faces joined by a soft edge bound by non-soft edges.
  #
  # @since 0.1.0
  class QuadFace
    
    # Evaluates if the entity is a face that forms part of a QuadFace.
    #
    # @see {QuadFace}
    #
    # @param [Sketchup::Entity] entity
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
    
    # Evaluates if the entity is a face that forms part of a QuadFace.
    #
    # @see {QuadFace}
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.dividing_edge?( entity )
      return false unless entity.is_a?( Sketchup::Edge )
      edge = entity
      return false unless edge.soft?
      return false unless edge.faces.size == 2
      edge.faces.all? { |face| self.is?( face ) }
    end
    
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    # @since 0.1.0
    def self.valid_geometry?( *args )
      # Validate arguments
      unless (1..2).include?( args.size )
        raise ArgumentError, 'Must be one or two faces.'
      end
      unless args.all? { |e| e.is_a?( Sketchup::Face ) }
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
        return false unless face1.edges.any? { |e| face2.edges.include?( e ) }
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
    
    # @return [Geom::PolygonMesh]
    # @since 0.1.0
    def mesh
      if @faces.size == 1
        @faces[0].mesh
      else
        face1, face2 = @faces
        pm1 = face1.mesh
        pm2 = face2.mesh
        # Merge the polygon from face2 with face1.
        # (i) This assumes @faces contains two valid triangular faces.
        polygon = pm2.polygons[0]
        polygon.map! { |index| pm2.point_at( index ) }
        pm1.add_polygon( *polygon )
        pm1
      end
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
  class SelectQuadFace
    
    # @since 0.1.0
    def initialize
      model = Sketchup.active_model
      # Find QuadFaces
      @faces = model.active_entities.select { |e| QuadFace.is?( e ) }
      # (!) Build QuadFace list
      # Build draw cache
      @edges = @faces.map { |quad| quad.edges }
      @edges.flatten!
      @edges.uniq!
      @edges.reject! { |e| e.soft? }
      @segments = @edges.map { |e| [e.start.position, e.end.position] }
      @lines = @segments.flatten
      # Used by onSetCursor
      @key_ctrl = false
      @key_shift = false
      
      @cursor         = TT::Cursor.get_id( :select )
      @cursor_add     = TT::Cursor.get_id( :select_add )
      @cursor_remove  = TT::Cursor.get_id( :select_remove )
      @cursor_toggle  = TT::Cursor.get_id( :select_toggle )
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
    def onLButtonDown( flags, x, y, view )
      ph = view.pick_helper
      picked_edge = nil
      picked_quad = nil
      # Pick faces
      ph.do_pick( x, y )
      entity = ph.picked_face
      if entity && @faces.include?( entity )
        quad = QuadFace.new( entity )
        picked_quad = quad
      end
      # Pick Edges
      # Hidden edges are not picked if Hidden Geometry is off.
      ph.init( x, y )
      for edge in @segments
        result = ph.pick_segment( edge )
        next unless result
        # Find the edge which the segment represented.
        index = @segments.index( edge )
        current_edge = @edges[index]
        if picked_quad
          # If a quad has been picked, choose edge connected to the quad - if
          # possible.
          if picked_quad.edges.include?( current_edge )
            picked_edge = current_edge
            break
          end
        else
          picked_edge = current_edge
          break
        end
      end
      # Determine what to pick.
      picked = nil
      if picked_edge
        picked = picked_edge
      elsif picked_quad
        picked = picked_quad.faces
      end
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      # Select the entities.
      entities = []
      entities << picked if picked
      selection = view.model.selection
      if key_ctrl && key_shift
        selection.remove( entities )
      elsif key_ctrl
        selection.add( entities )
      elsif key_shift
        selection.toggle( entities )
      else
        selection.clear
        selection.add( entities )
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyDown
    #
    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyUp
    #
    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor()
      false
    end
    
    # @since 0.1.0
    def draw( view )
      unless @lines.empty?
        view.line_stipple = ''
        view.line_width = 3
        view.drawing_color = 'red'
        view.draw_lines( @lines )
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onSetCursor
    #
    # @since 1.0.0
    def onSetCursor
      if @key_ctrl && @key_shift
        cursor = @cursor_remove
      elsif @key_ctrl
        cursor = @cursor_add
      elsif @key_shift
        cursor = @cursor_toggle
      else
        cursor = @cursor
      end
      UI.set_cursor( cursor )
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