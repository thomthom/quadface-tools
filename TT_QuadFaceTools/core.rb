#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.4', 'TT QuadFace Tools')

#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  ### PREFERENCES ### ----------------------------------------------------------
  
  @settings = TT::Settings.new( PLUGIN_ID )
  @settings.set_default( :context_menu, false )
  @settings.set_default( :connect_splits, 1 )
  @settings.set_default( :connect_pinch, 0 )
  
  def self.settings; @settings; end

  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  require File.join( PATH, 'entities.rb' )
  require File.join( PATH, 'tools.rb' )
  require File.join( PATH, 'edge_connect.rb' )
  require File.join( PATH, 'mesh_converter.rb' )
  require File.join( PATH, 'gl.rb' )
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    
    @commands = {}
    def self.commands; @commands; end
    
    # Commands
    cmd = UI::Command.new( 'Select' )   { self.select_quadface_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Select_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Select_24.png' )
    cmd.status_bar_text = 'Select Tool.'
    cmd.tooltip = 'Select'
    cmd_select = cmd
    @commands[:select] = cmd
    
    cmd = UI::Command.new( 'Grow Selection' ) { self.selection_grow }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionGrow_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionGrow_24.png' )
    cmd.status_bar_text = 'Grow Selection.'
    cmd.tooltip = 'Grow Selection'
    cmd_selection_grow = cmd
    @commands[:selection_grow] = cmd
    
    cmd = UI::Command.new( 'Shrink Selection' ) { self.selection_shrink }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionShrink_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionShrink_24.png' )
    cmd.status_bar_text = 'Shrink Selection.'
    cmd.tooltip = 'Shrink Selection'
    cmd_selection_shrink = cmd
    @commands[:selection_shrink] = cmd
    
    cmd = UI::Command.new( 'Select Ring' ) { self.select_rings }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectRing_24.png' )
    cmd.status_bar_text = 'Select Ring.'
    cmd.tooltip = 'Select Ring'
    cmd_select_ring = cmd
    @commands[:select_ring] = cmd
    
    cmd = UI::Command.new( 'Grow Ring' )  { self.select_rings( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowRing_24.png' )
    cmd.status_bar_text = 'Grow Ring.'
    cmd.tooltip = 'Grow Ring'
    cmd_grow_ring = cmd
    @commands[:grow_ring] = cmd
    
    cmd = UI::Command.new( 'Shrink Ring' )  { self.shrink_rings }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkRing_24.png' )
    cmd.status_bar_text = 'Shrink Ring.'
    cmd.tooltip = 'Shrink Ring'
    cmd_shrink_ring = cmd
    @commands[:shrink_ring] = cmd
    
    cmd = UI::Command.new( 'Select Loop' ) { self.select_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectLoop_24.png' )
    cmd.status_bar_text = 'Select Loop.'
    cmd.tooltip = 'Select Loop'
    cmd_select_loop = cmd
    @commands[:select_loop] = cmd
    
    cmd = UI::Command.new( 'Grow Loop' )  { self.select_loops( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowLoop_24.png' )
    cmd.status_bar_text = 'Grow Loop.'
    cmd.tooltip = 'Grow Loop'
    cmd_grow_loop = cmd
    @commands[:grow_loop] = cmd
    
    cmd = UI::Command.new( 'Shrink Loop' )  { self.shrink_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkLoop_24.png' )
    cmd.status_bar_text = 'Shrink Loop.'
    cmd.tooltip = 'Shrink Loop'
    cmd_shrink_loop = cmd
    @commands[:shrink_loop] = cmd
    
    cmd = UI::Command.new( 'Select Region to Loop' )  { self.region_to_loop }
    cmd.status_bar_text = 'Select a loop of edges around selected entities.'
    cmd.tooltip = 'Select a loop of edges around selected entities'
    cmd_region_to_loop = cmd
    @commands[:region_to_loop] = cmd
    
    cmd = UI::Command.new( 'Connect Edges' )   { self.connect_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Connect_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Connect_24.png' )
    cmd.status_bar_text = 'Connect Edges Tool.'
    cmd.tooltip = 'Connect Edges'
    cmd_connect = cmd
    @commands[:connect] = cmd
    
    cmd = UI::Command.new( 'Insert Loops' )   { self.insert_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'InsertLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'InsertLoop_24.png' )
    cmd.status_bar_text = 'Insert Loops.'
    cmd.tooltip = 'Insert Loops'
    cmd_insert_loops = cmd
    @commands[:insert_loops] = cmd
    
    cmd = UI::Command.new( 'Remove Loops' )   { self.remove_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'RemoveLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'RemoveLoop_24.png' )
    cmd.status_bar_text = 'Remove Loops.'
    cmd.tooltip = 'Remove Loops'
    cmd_remove_loops = cmd
    @commands[:remove_loops] = cmd
    
    cmd = UI::Command.new( 'Triangulate' )  { self.triangulate_selection}
    cmd.small_icon = File.join( PATH_ICONS, 'Triangulate_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Triangulate_24.png' )
    cmd.status_bar_text = 'Triangulate selected QuadFaces.'
    cmd.tooltip = 'Triangulate Selected QuadFaces'
    cmd_triangulate_selection = cmd
    @commands[:triangulate] = cmd
    
    cmd = UI::Command.new( 'Remove Triangulation' )  { self.remove_triangulation}
    cmd.status_bar_text = 'Remove triangulation from selected planar Quads.'
    cmd.tooltip = 'Remove triangulation from selected planar Quads'
    cmd_remove_triangulation = cmd
    @commands[:remove_triangulation] = cmd
    
    cmd = UI::Command.new( 'Connected Mesh to Quads' )  {
      self.convert_connected_mesh_to_quads
    }
    cmd.small_icon = File.join( PATH_ICONS, 'ConvertToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ConvertToQuads_24.png' )
    cmd.status_bar_text = 'Convert connected mesh to Quads.'
    cmd.tooltip = 'Convert Connected Mesh to Quads'
    cmd_convert_connected_mesh_to_quads = cmd
    @commands[:mesh_to_quads] = cmd
    
    cmd = UI::Command.new( 'Blender Quads to SketchUp Quads' )  {
      self.convert_blender_quads_to_sketchup_quads
    }
    cmd.status_bar_text = 'Convert Blender quads to SketchUp Quads.'
    cmd.tooltip = 'Convert Blender quads to SketchUp Quads'
    cmd_convert_blender_quads_to_sketchup_quads = cmd
    @commands[:blender_to_quads] = cmd
    
    cmd = UI::Command.new( 'Smooth Quads' )  {
      self.smooth_quad_mesh
    }
    cmd.status_bar_text = 'Smooths the selected Quads\' edges.'
    cmd.tooltip = 'Smooths the selected Quads\' edges'
    cmd_smooth_quad_mesh = cmd
    @commands[:smooth_quads] = cmd
    
    cmd = UI::Command.new( 'Unsmooth Quads' )  {
      self.unsmooth_quad_mesh
    }
    cmd.status_bar_text = 'Unsmooth the selected Quads\' edges.'
    cmd.tooltip = 'Unsmooth the selected Quads\' edges'
    cmd_unsmooth_quad_mesh = cmd
    @commands[:unsmooth_quads] = cmd
    
    cmd = UI::Command.new( 'Make Planar' )  {
      self.make_planar
    }
    cmd.status_bar_text = 'Projects the selected faces to a best fit plane.'
    cmd.tooltip = 'Projects selected faces to a best fit plane'
    cmd_make_planar = cmd
    @commands[:make_planar] = cmd
    
    cmd = UI::Command.new( 'Context Menu' )  {
      @settings[ :context_menu ] = !@settings[ :context_menu ]
    }
    cmd.set_validation_proc  {
      ( @settings[:context_menu] ) ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.status_bar_text = 'Toggles the context menu.'
    cmd.tooltip = 'Toggles the context menu'
    cmd_toggle_context_menu = cmd
    @commands[:context_menu] = cmd
    
    
    # Menus
    m = TT.menu( 'Tools' ).add_submenu( 'QuadFace Tools' )
    m.add_item( cmd_select )
    m.add_separator
    m.add_item( cmd_selection_grow )
    m.add_item( cmd_selection_shrink )
    m.add_separator
    m.add_item( cmd_select_ring )
    m.add_item( cmd_select_loop )
    m.add_item( cmd_region_to_loop )
    m.add_separator
    m.add_item( cmd_smooth_quad_mesh )
    m.add_item( cmd_unsmooth_quad_mesh )
    m.add_separator
    m.add_item( cmd_connect )
    m.add_item( cmd_insert_loops )
    m.add_item( cmd_remove_loops )
    m.add_separator
    m.add_item( cmd_triangulate_selection )
    m.add_item( cmd_remove_triangulation )
    m.add_separator
    m.add_item( cmd_make_planar )
    m.add_separator
    sub_menu = m.add_submenu( 'Convert' )
    sub_menu.add_item( cmd_convert_connected_mesh_to_quads )
    sub_menu.add_item( cmd_convert_blender_quads_to_sketchup_quads )
    m.add_separator
    sub_menu = m.add_submenu( 'Preferences' )
    sub_menu.add_item( cmd_toggle_context_menu )
    
    # Context menu
    UI.add_context_menu_handler { |context_menu|
      if @settings[ :context_menu ]
        m = context_menu.add_submenu( 'QuadFace Tools' )
        m.add_item( cmd_selection_grow )
        m.add_item( cmd_selection_shrink )
        m.add_separator
        m.add_item( cmd_select_ring )
        m.add_item( cmd_select_loop )
        m.add_item( cmd_region_to_loop )
        # (i) Loop stepping menu items removed as they are too impractical to
        #     operate via menus which require multiple clicks to trigger.
        m.add_separator
        m.add_item( cmd_smooth_quad_mesh )
        m.add_item( cmd_unsmooth_quad_mesh )
        m.add_separator
        m.add_item( cmd_connect )
        m.add_item( cmd_insert_loops )
        m.add_item( cmd_remove_loops )
        m.add_separator
        m.add_item( cmd_triangulate_selection )
        m.add_item( cmd_remove_triangulation )
        m.add_separator
        m.add_item( cmd_make_planar )
        m.add_separator
        sub_menu = m.add_submenu( 'Convert' )
        sub_menu.add_item( cmd_convert_connected_mesh_to_quads )
        sub_menu.add_item( cmd_convert_blender_quads_to_sketchup_quads )
      end
    }
    
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
    toolbar.add_separator
    toolbar.add_item( cmd_connect )
    toolbar.add_item( cmd_insert_loops )
    toolbar.add_item( cmd_remove_loops )
    toolbar.add_separator
    toolbar.add_item( cmd_triangulate_selection )
    toolbar.add_item( cmd_convert_connected_mesh_to_quads )
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @since 0.1.0
  def self.select_quadface_tool
    Sketchup.active_model.select_tool( SelectQuadFaceTool.new )
  end
  
  
  # @since 0.3.0
  def self.connect_tool
    Sketchup.active_model.select_tool( ConnectTool.new )
  end
  
  
  # @since 0.3.0
  def self.insert_loops
    model = Sketchup.active_model
    selection = model.selection
    entities = []
    # Find Edge Rings in Selection
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      next if QuadFace.dividing_edge?( entity )
      next if entities.include?( entity )
      entities.concat( find_edge_ring( entity ) )
    end
    # Edge Connect
    TT::Model.start_operation( 'Insert Loops' )
    edge_connect = EdgeConnect.new( entities )
    edges = edge_connect.connect!
    model.commit_operation
    # Select
    selection.clear
    selection.add( edges )
  end
  
  
  # @since 0.3.0
  def self.remove_loops
    model = Sketchup.active_model
    selection = model.selection
    # Proccess each loop
    TT::Model.start_operation( 'Remove Loops' )
    for entity in selection.to_a
      next unless entity.valid?
      next unless entity.is_a?( Sketchup::Edge )
      next if QuadFace.dividing_edge?( entity )
      loop = find_edge_loop( entity )
      vertices = {}
      # Make loop edges planar between neighbour faces.
      for edge in loop
        next unless edge.faces.all? { |face| QuadFace.is?( face ) }
        quads = edge.faces.map { |face| QuadFace.new( face ) }
        quad_edges = quads.map { |quad| quad.edges }.flatten.uniq
        for vertex in edge.vertices
          next if vertices[ vertex ]
          edges = vertex.edges & quad_edges - [edge]
          e1, e2 = edges
          v1 = e1.other_vertex( vertex )
          v2 = e2.other_vertex( vertex )
          line = [ v1.position, v2.position ]
          new_pt = vertex.position.project_to_line( line )
          vertices[ vertex ] = vertex.position.vector_to( new_pt )
        end
      end
      # Calculate vectors to make the loop vertices co-linear with their
      # adjecent edges - required to merge the quads connected to the loop.
      vertex_entities = []
      vectors = []
      for vertex, vector in vertices
        next unless vector.valid?
        vertex_entities << vertex
        vectors << vector
      end
      # Remove loop edges.
      erase_edges = []
      erase_faces = []
      new_quads = []
      for edge in loop
        next unless edge.faces.all? { |face| QuadFace.is?( face ) }
        quads = edge.faces.map { |face| QuadFace.new( face ) }
        # Find the vertices of the merged face.
        q1, q2 = quads
        e1 = q1.opposite_edge( edge )
        e2 = q2.opposite_edge( edge )
        pts = q1.edge_positions( e1 ) + q2.edge_positions( e2 )
        # Mark edge for deletion.
        erase_edges << edge
        # If the connected quads are triangulated or the merged face is not
        # planar, erase the faces and re-generate new quad.
        planar = TT::Geom3d.planar_points?( pts )
        triangulated = quads.any? { |quad| quad.triangulated? }
        if !planar || triangulated
          erase_faces.concat( q1.faces + q2.faces )
          new_quads << pts
        end
      end
      # Reshape and merge the entities.
      active_entities = model.active_entities
      active_entities.erase_entities( erase_faces )
      active_entities.transform_by_vectors( vertex_entities, vectors )
      active_entities.erase_entities( erase_edges )
      for points in new_quads
        self.fill_face( active_entities, points )
      end
    end
    model.commit_operation
  end
  
  
  # Ensures that all quad faces in the current selection is triangulated. This
  # prevents SketchUp's auto-fold feature to break the quad face when it's
  # transformed such that it becomes non-planar.
  #
  # @since 0.1.0
  def self.triangulate_selection
    model = Sketchup.active_model
    selection = model.selection
    new_selection = []
    TT::Model.start_operation( 'Triangulate QuadFaces' )
    for entity in selection.to_a
      next unless QuadFace.is?( entity )
      quadface = QuadFace.new( entity )
      quadface.triangulate!
      new_selection.concat( quadface.faces )
    end
    model.commit_operation
    selection.add( new_selection )
  end
  
  
  # Converts selected planar triangualted quads into native quads.
  #
  # @since 0.2.0
  def self.remove_triangulation
    model = Sketchup.active_model
    TT::Model.start_operation( 'Remove Triangulation' )
    for entity in model.selection.to_a
      next unless QuadFace.is?( entity )
      quadface = QuadFace.new( entity )
      next unless quadface.planar?
      quadface.detriangulate!
    end
    model.commit_operation
  rescue
    model.abort_operation
    raise
  end
  
  
  # Smooths and hides the edges of selected quads.
  #
  # @since 0.2.0
  def self.smooth_quad_mesh
    model = Sketchup.active_model
    TT::Model.start_operation( 'Smooth Quads' )
    for entity in model.selection
      next unless QuadFace.is?( entity )
      quadface = QuadFace.new( entity )
      quadface.edges.each { |edge|
        next if edge.faces.size == 1
        edge.hidden = true
        edge.smooth = true
      }
    end
    model.commit_operation
  end
  
  
  # Unmooths and unhides the edges of selected quads.
  #
  # @since 0.2.0
  def self.unsmooth_quad_mesh
    model = Sketchup.active_model
    TT::Model.start_operation( 'Unsmooth Quads' )
    for entity in model.selection
      next unless QuadFace.is?( entity )
      quadface = QuadFace.new( entity )
      quadface.edges.each { |edge|
        edge.hidden = false
        edge.smooth = false
        edge.soft = false
      }
    end
    model.commit_operation
  end
  
  
  # Project the selected entities to a best fit plane.
  #
  # @since 0.2.0
  def self.make_planar
    model = Sketchup.active_model
    selection = model.selection
    vertices = []
    for face in model.selection
      vertices << face.vertices if face.is_a?( Sketchup::Face )
    end
    vertices.flatten!
    vertices.uniq!
    return false if vertices.empty?
    TT::Model.start_operation( 'Make Planar' )
    # Triangulate connected quads to ensure they are not broken.
    for vertex in vertices
      for face in vertex.faces
        next if selection.include?( face )
        next unless QuadFace.is?( face )
        quad = QuadFace.new( face )
        next if quad.triangulated?
        quad.triangulate!
      end
    end
    # Project the vertices to a best fit plane.
    plane = Geom.fit_plane_to_points( vertices )
    entities = []
    vectors = []
    for vertex in vertices
      new_point = vertex.position.project_to_plane( plane )
      vector = vertex.position.vector_to( new_point )
      next unless vector.valid?
      entities << vertex
      vectors << vector
    end
    model.active_entities.transform_by_vectors( entities, vectors )
    model.commit_operation
  rescue
    model.abort_operation
    raise
  end
  
  
  # DAE models from Blender with quads imports into SketchUp as triangles with
  # a hidden dividing edge instead of a soft one. This routine converts these
  # quads into SketchUp quads.
  #
  # @since 0.2.0
  def self.convert_blender_quads_to_sketchup_quads
    model = Sketchup.active_model
    selection = model.selection
    entities = ( selection.empty? ) ? model.active_entities : selection
    TT::Model.start_operation( 'Blender Quads to SketchUp Quads' )
      self.convert_blender_quads( entities )
    model.commit_operation
  end
  
  
  # Converts two sets of triangles sharing by a hidden edge with hard edges into
  # QuadFace compatible quads.
  #
  # @param [Enumerable<Sketchup::Entity>] entities
  #
  # @since 0.2.0
  def self.convert_blender_quads( entities )
    for entity in entities
      if TT::Instance.is?( entity )
        definition = TT::Instance.definition( entity )
        self.convert_blender_quads( definition.entities )
      end
      next unless entity.is_a?( Sketchup::Edge )
      next unless entity.faces.size == 2
      next unless entity.hidden?
      next unless entity.faces.all? { |face|
        edges = face.edges - [entity]
        face.vertices.size == 3 &&
        edges.all? { |edge| !( edge.soft? || edge.hidden? ) }
      }
      entity.hidden = false
      entity.soft = true
      entity.smooth = true
    end
  end
  
  
  # Converts selected entities into edge loops.
  #
  # @see http://wiki.blender.org/index.php/Template:Release_Notes/2.42/Mesh/Editing
  #
  # @since 0.2.0
  def self.region_to_loop
    model = Sketchup.active_model
    selection = model.selection
    # Collect faces in selection.
    region = []
    for entity in selection
      if entity.is_a?( Sketchup::Face )
        region << entity
      elsif entity.is_a?( Sketchup::Edge )
        region << self.connected_faces( entity )
      end
    end
    region.flatten!
    region.uniq!
    faces = region.map { |face|
      if face.is_a?( QuadFace )
        face.faces
      else
        face
      end
    }
    faces.flatten!
    faces.uniq!
    # Find edges bordering the faces.
    edges = []
    for face in region
      for edge in face.edges
        if edge.faces.size == 1
          edges << edge
        elsif !edge.faces.all? { |f| faces.include?( f ) }
          edges << edge
        end
      end
    end
    edges.uniq!
    # Select loops.
    selection.clear
    selection.add( edges )
  end
  
  
  # Selects rings based on the selected entities.
  #
  # @todo Support face rings.
  #
  # @param [Boolean] step
  #
  # @since 0.1.0
  def self.select_rings( step = false )
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      #next if entity.soft?
      next if QuadFace.dividing_edge?( entity )
      entities.concat( find_edge_ring( entity, step ) )
    end
    # Select
    selection.add( entities )
  end
  
  
  # Shrink ring loops.
  #
  # @todo Support face rings.
  #
  # @since 0.1.0
  def self.shrink_rings
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      #next if entity.soft?
      next if QuadFace.dividing_edge?( entity )
      next unless entity.faces.size == 2
      # Check neighbouring faces if their opposite edges are selected.
      # Deselect any edge where not all opposite edges are selected.
      unless entity.faces.all? { |face|
        if QuadFace.is?( face )
          quad = QuadFace.new( face )
          edge = quad.opposite_edge( entity )
          selection.include?( edge )
        else
          false
        end
      }
        entities << entity
      end
    end
    # Select
    selection.remove( entities )
  end
  
  
  # Selects loops based on the selected entities.
  #
  # @todo Support face loops.
  #
  # @param [Boolean] step
  #
  # @since 0.1.0
  def self.select_loops( step = false )
    selection = Sketchup.active_model.selection
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      #next if entity.soft?
      next if QuadFace.dividing_edge?( entity )
      entities.concat( find_edge_loop( entity, step ) )
    end
    # Select
    selection.add( entities )
  end
  
  
  # Shrink ring loops.
  #
  # @todo Support face rings.
  #
  # @since 0.1.0
  def self.shrink_loops
    selection = Sketchup.active_model.selection
    selected = selection.to_a
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      #next if entity.soft?
      next if QuadFace.dividing_edge?( entity )
      next unless entity.faces.size == 2
      # Check next edges in loop, if they are not all selected, deselect the
      # edge.
      edges = find_edge_loop( entity, true )
      unless ( edges & selected ).size == edges.size
        entities << entity
      end
    end
    # Select
    selection.remove( entities )
  end
  
  
  # Extend the selection by one entity from the current selection set.
  #
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
  
  
  # Shrinks the selection by one entity from the current selection set.
  #
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
  #
  # @param [Sketchup::Edge]
  #
  # @return [Array<Sketchup::Edge>]
  # @since 0.1.0
  def self.find_edge_loop( origin_edge, step = false )
    raise ArgumentError, 'Invalid Edge' unless origin_edge.is_a?( Sketchup::Edge )
    # Find initial connected faces
    face_count = origin_edge.faces.size
    return false unless ( 1..2 ).include?( face_count )
    faces = self.connected_faces( origin_edge )
    # Find existing entities affecting the loop.
    selected_edges = origin_edge.model.selection.select { |e| e.is_a?( Sketchup::Edge ) }    
    # Find edge loop.
    step_limit = 0
    loop = []
    stack = [ origin_edge ]
    until stack.empty?
      edge = stack.shift
      # Find connected edges
      next_vertices = []
      for v in edge.vertices
        edges = v.edges.select { |e| !QuadFace.dividing_edge?( e ) }
        next if edges.size > 4 # Stop at forks
        next if edges.any? { |e| loop.include?( e ) }
        next_vertices << v
      end
      # Add current edge to loop stack.
      loop << edge
      # Pick next edges
      valid_edges = 0
      for vertex in next_vertices
        for e in vertex.edges
          next if e == edge
          next if QuadFace.dividing_edge?( e )
          next if faces.any? { |f| f.edges.include?( e ) }
          next if loop.include?( e )
          next if selected_edges.include?( e ) # (?) Needed?
          next unless e.faces.size == face_count
          valid_edges += 1
          stack << e
          faces.concat( self.connected_faces( e ) )
        end # for e
      end # for vertex
      # Stop if the loop is step-grown.
      if step
        step_limit = valid_edges if edge == origin_edge
        break if loop.size > step_limit
      end
    end # until
    loop
  end
  
  
  # ----- HELPER METHOD (!) Move to EntitiesProvider ----- #
  
  
  # @param [#faces] entity
  #
  # @return [Array<Sketchup::Face,QuadFace>]
  # @since 0.1.0
  def self.connected_faces( entity )
    faces = []
    for face in entity.faces
      if QuadFace.is?( face )
        faces << QuadFace.new( face )
      else
        faces << face
      end
    end
    faces
  end
  
  
  # @param [Sketchup::Edge]
  #
  # @return [Array<QuadFace>]
  # @since 0.1.0
  def self.connected_quad_faces( edge )
    # Get connected faces
    valid_faces = edge.faces.select { |f| QuadFace.is?( f ) }
    quads = valid_faces.map { |face| QuadFace.new( face ) }
  end
  
  
  # Wrapper for creating faces where the points might belong to QuadFaces that
  # are not planar.
  #
  # A QuadFace is returned for all faces with four vertices.
  #
  # @param [Sketchup::Entities] entities 
  # @param [Array<Geom::Point3d>] points
  #
  # @return [QuadFace,Sketchup::Face]
  # @since 0.3.0
  def self.add_face( entities, points )
    if points.size == 4 && !TT::Geom3d.planar_points?( points )
      face1 = entities.add_face( points[0], points[1], points[2] )
      face2 = entities.add_face( points[2], points[1], points[3] )
      edge = ( face1.edges & face2.edges )[0]
      edge.soft = true
      edge.smooth = true
      QuadFace.new( face1 )
    else
      face = entities.add_face( points )
      face = QuadFace.new( face ) if points.size == 4
      face
    end
  end
  
  
  # Acts like #add_face, but doesn't have the overhead of returning QuadFaces.
  #
  # @see #add_face
  #
  # @param [Sketchup::Entities] entities 
  # @param [Array<Geom::Point3d>] points
  #
  # @return [Nil]
  # @since 0.3.0
  def self.fill_face( entities, points )
    if points.size == 4 && !TT::Geom3d.planar_points?( points )
      face1 = entities.add_face( points[0], points[1], points[2] )
      face2 = entities.add_face( points[0], points[2], points[3] )
      edge = ( face1.edges & face2.edges )[0]
      edge.soft = true
      edge.smooth = true
    else
      entities.add_face( points )
    end
    nil
  end
  
  
  # @since 0.1.0
  def self.transform
    # (!)
    # Transform a set of entities related to quadfaces - ensuring that native
    # quadfaces are triangulated correctly with a soft & smooth divider edge.
  end
  
  
  # @param [Sketchup::Face] triangle1
  # @param [Sketchup::Face] triangle2
  #
  # @return [Sketchup::Edge,Nil]
  # @since 0.1.0
  def self.common_edge( triangle1, triangle2 )
    intersect = triangle1.edges & triangle2.edges
    ( intersect.empty? ) ? nil : intersect[0]
  end
  
  
  # @overload convert_to_quad( native_quad )
  #   @param [Sketchup::Face] native_quad
  #
  # @overload convert_to_quad( triangle1, triangle2, edge )
  #   @param [Sketchup::Face] triangle1
  #   @param [Sketchup::Face] triangle2
  #   @param [Sketchup::Edge] edge Edge separating the two triangles.
  #
  # @return [QuadFace]
  # @since 0.1.0
  def self.convert_to_quad( *args )
    if args.size == 1
      face = args[0]
      for edge in face.edges
        if edge.soft?
          edge.soft = false
          edge.hidden = true
        end
      end
      QuadFace.new( face )
    elsif args.size == 3
      # (?) Third edge argument required? Can be inferred by the two triangles.
      face1, face2, dividing_edge = args
      dividing_edge.soft = true
      dividing_edge.smooth = true
      for face in [ face1, face2 ]
        for edge in face.edges
          next if edge == dividing_edge
          if edge.soft?
            edge.soft = false
            edge.hidden = true
          end
        end
      end
      QuadFace.new( face1 )
    else
      raise ArgumentError, 'Incorrect number of arguments.'
    end
  end
  

  ### DEBUG ### ----------------------------------------------------------------  
  
  
  # @since 0.3.0
  def self.debug_loop
    model = Sketchup.active_model
    sel = model.selection
    model.start_operation( 'Debug Loop' )
    for entity in sel
      next unless QuadFace.is?( entity )
      quad = QuadFace.new( entity )
      quad.outer_loop.each_with_index { |e,i|
        pt1 = e.start.position
        pt2 = e.end.position
        mid = Geom.linear_combination( 0.5, pt1, 0.5, pt2 )
        model.active_entities.add_text( i.to_s, mid, [-2,-2,2] )
        
        start = ( quad.edge_reversed?( e ) ) ? pt2 : pt1
        pt3 = Geom.linear_combination( 0.5, start, 0.5, mid )
        model.active_entities.add_text( 'S', pt3, [-1,-1,1] )
      }
    end
    model.commit_operation
  end
  
  
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
    #load __FILE__
    # Supporting files
    x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
      load file
    }
    x.length
  ensure
    $VERBOSE = original_verbose
  end
  
end # module

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------