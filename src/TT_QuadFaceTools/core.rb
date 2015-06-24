#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', 'QuadFace Tools' )

module TT::Plugins::QuadFaceTools
  
  
  ### PREFERENCES ### ----------------------------------------------------------

  # TT::Plugins::QuadFaceTools::Settings.write('DebugDisplayOffsetLoopTool', true)

  @settings = TT::Settings.new( PLUGIN_ID )
  # UI
  @settings.set_default( :context_menu, false )
  # Select Tool
  @settings.set_default( :ui_2d, true )
  @settings.set_default( :ui_show_poles, false )
  # Connect Edge
  @settings.set_default( :connect_splits, 1 )
  @settings.set_default( :connect_pinch, 0 )
  @settings.set_default( :connect_window_x, 300 )
  @settings.set_default( :connect_window_y, 300 )
  # UV Mapping
  @settings.set_default( :uv_draw_uv_grid, false )
  @settings.set_default( :uv_continuous, true )
  @settings.set_default( :uv_scale_proportional, false )
  @settings.set_default( :uv_scale_absolute, false )
  begin
    if @settings[ :uv_scale_absolute ]
      @settings.set_default( :uv_u_scale, 500.mm )
      @settings.set_default( :uv_v_scale, 500.mm )
    else
      @settings.set_default( :uv_u_scale, 1.0 )
      @settings.set_default( :uv_v_scale, 1.0 )
    end
  rescue
    # (!) HOTFIX
    # There has been reports of loading errors which is related to loading
    # these settings. The Settings manager loads nil values and tries to cast
    # them into Lengths.
    #
    # Possibly it's due to errors in the UV mapping tool which doesn't error
    # check and stores nil values. Until that is tracked down this little
    # hotfix resets the UV scale settings so the tool doesn't stop working.
    @settings[ :uv_u_scale ] = 1.0
    @settings[ :uv_v_scale ] = 1.0
    @settings.set_default( :uv_u_scale, 1.0 )
    @settings.set_default( :uv_v_scale, 1.0 )
    TT.debug( 'QuadFace Tools - Error loading UV scale.' )
  end
  
  def self.settings; @settings; end

  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  require File.join( PATH, 'entities.rb' )
  require File.join( PATH, 'tools.rb' )
  require File.join( PATH, 'uv_mapping.rb' )
  require File.join( PATH, 'edge_connect.rb' )
  require File.join( PATH, 'mesh_converter.rb' )
  require File.join( PATH, 'gl.rb' )
  require File.join( PATH, 'window.rb' )
  require File.join( PATH, 'exporter_obj.rb' )
  require 'TT_QuadFaceTools/importers/obj'
  require 'TT_QuadFaceTools/settings'
  require 'TT_QuadFaceTools/tools/offset'

  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )

    # Importers
    Sketchup.register_importer(ObjImporter.new)

    
    @commands = {}
    def self.commands; @commands; end
    
    # Commands
    cmd = UI::Command.new( 'Select' )   { self.select_quadface_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Select_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Select_24.png' )
    cmd.status_bar_text = 'Selection tool to work with quads.'
    cmd.tooltip = 'Select'
    cmd_select = cmd
    @commands[:select] = cmd
    
    cmd = UI::Command.new( 'Grow Selection' ) { self.selection_grow }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionGrow_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionGrow_24.png' )
    cmd.status_bar_text = 'Expands the selection to the neighbouring entities.'
    cmd.tooltip = 'Grow Selection'
    cmd_selection_grow = cmd
    @commands[:selection_grow] = cmd
    
    cmd = UI::Command.new( 'Shrink Selection' ) { self.selection_shrink }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectionShrink_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectionShrink_24.png' )
    cmd.status_bar_text = 'Removes the bordering entities from a selection.'
    cmd.tooltip = 'Shrink Selection'
    cmd_selection_shrink = cmd
    @commands[:selection_shrink] = cmd
    
    cmd = UI::Command.new( 'Select Ring' ) { self.select_rings }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectRing_24.png' )
    cmd.status_bar_text = 'Selects rings of edges and faces based on the current selection.'
    cmd.tooltip = 'Select Ring'
    cmd_select_ring = cmd
    @commands[:select_ring] = cmd
    
    cmd = UI::Command.new( 'Grow Ring' )  { self.select_rings( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowRing_24.png' )
    cmd.status_bar_text = 'Incrementally expands the ring selection.'
    cmd.tooltip = 'Grow Ring'
    cmd_grow_ring = cmd
    @commands[:grow_ring] = cmd
    
    cmd = UI::Command.new( 'Shrink Ring' )  { self.shrink_rings }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkRing_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkRing_24.png' )
    cmd.status_bar_text = 'Incrementally shrinks the ring selection.'
    cmd.tooltip = 'Shrink Ring'
    cmd_shrink_ring = cmd
    @commands[:shrink_ring] = cmd
    
    cmd = UI::Command.new( 'Select Loop' ) { self.select_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'SelectLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SelectLoop_24.png' )
    cmd.status_bar_text = 'Selects loops of edges and faces based on the current selection.'
    cmd.tooltip = 'Select Loop'
    cmd_select_loop = cmd
    @commands[:select_loop] = cmd
    
    cmd = UI::Command.new( 'Grow Loop' )  { self.select_loops( true ) }
    cmd.small_icon = File.join( PATH_ICONS, 'GrowLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'GrowLoop_24.png' )
    cmd.status_bar_text = 'Incrementally expands the loop selection.'
    cmd.tooltip = 'Grow Loop'
    cmd_grow_loop = cmd
    @commands[:grow_loop] = cmd
    
    cmd = UI::Command.new( 'Shrink Loop' )  { self.shrink_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'ShrinkLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ShrinkLoop_24.png' )
    cmd.status_bar_text = 'Incrementally shrinks the loop selection.'
    cmd.tooltip = 'Shrink Loop'
    cmd_shrink_loop = cmd
    @commands[:shrink_loop] = cmd

    cmd = UI::Command.new( 'Offset Loop' )  { self.offset_loop_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'OffsetLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'OffsetLoop_24.png' )
    cmd.status_bar_text = 'Offset an edge loop.'
    cmd.tooltip = 'Offset Loop'
    cmd_offset_loop_tool = cmd
    @commands[:offset_loop_tool] = cmd
    
    cmd = UI::Command.new( 'Selection Region to Loop' )  { self.region_to_loop }
    cmd.status_bar_text = 'Select a loop of edges bordering the selected entities.'
    cmd.tooltip = 'Selection Region to Loop'
    cmd_region_to_loop = cmd
    @commands[:region_to_loop] = cmd
    
    cmd = UI::Command.new( 'Selection Loop to Region' )  { self.loop_to_region }
    cmd.status_bar_text = 'Select a region based on a selected loop of edge and a marker edge.'
    cmd.tooltip = 'Selection Loop to Region'
    cmd_loop_to_region = cmd
    @commands[:loop_to_region] = cmd
    
    cmd = UI::Command.new( 'Select Quads from Edges' )  {
      self.select_quads_from_edges
    }
    cmd.status_bar_text = 'Selects quads with two or more edges selected.'
    cmd.tooltip = 'Select Quads from Edges'
    cmd_select_quads_from_edges = cmd
    @commands[:select_quads_from_edges] = cmd
    
    cmd = UI::Command.new( 'Select Bounding Edges' )  {
      self.select_bounding_edges
    }
    cmd.status_bar_text = 'Selects all edges that bounds a quad or face.'
    cmd.tooltip = 'Select Bounding Edges'
    cmd_select_bounding_edges = cmd
    @commands[:select_bounding_edges] = cmd
    
    cmd = UI::Command.new( 'Deselect Triangulation' )  {
      self.deselect_triangulation
    }
    cmd.status_bar_text = 'Deselects all dividing edges in triangulated quads.'
    cmd.tooltip = 'Deselect Triangulation'
    cmd_deselect_triangulation = cmd
    @commands[:deselect_triangulation] = cmd
    
    cmd = UI::Command.new( 'Connect Edges' )   { self.connect_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Connect_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Connect_24.png' )
    cmd.status_bar_text = 'Creates new edges between adjacent pairs of selected edges.'
    cmd.tooltip = 'Connect Edges Tool'
    cmd_connect = cmd
    @commands[:connect] = cmd
    
    cmd = UI::Command.new( 'Insert Loops' )   { self.insert_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'InsertLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'InsertLoop_24.png' )
    cmd.status_bar_text = 'Insert loops from the current set of selected edges.'
    cmd.tooltip = 'Insert Loops'
    cmd_insert_loops = cmd
    @commands[:insert_loops] = cmd
    
    cmd = UI::Command.new( 'Remove Loops' )   { self.remove_loops }
    cmd.small_icon = File.join( PATH_ICONS, 'RemoveLoop_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'RemoveLoop_24.png' )
    cmd.status_bar_text = 'Remove the loops which the selected edges are part of.'
    cmd.tooltip = 'Remove Loops'
    cmd_remove_loops = cmd
    @commands[:remove_loops] = cmd
    
    cmd = UI::Command.new( 'Build Corners' )   { self.build_corners }
    cmd.small_icon = File.join( PATH_ICONS, 'BuildCorners_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'BuildCorners_24.png' )
    cmd.status_bar_text = 'Builds a quad corner based on the selected edges to make an edge-loop turn. '
    cmd.tooltip = 'Build Corners'
    cmd_build_corners = cmd
    @commands[:build_corners] = cmd
    
    cmd = UI::Command.new( 'Build Ends' )   { self.build_ends }
    cmd.small_icon = File.join( PATH_ICONS, 'BuildEnds_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'BuildEnds_24.png' )
    cmd.status_bar_text = 'Builds a quad ending to two parallel loops based on the selected edges.'
    cmd.tooltip = 'Build Ends'
    cmd_build_ends = cmd
    @commands[:build_ends] = cmd
    
    cmd = UI::Command.new( 'Flip Triangulation Tool' )  { self.flip_edge_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'FlipEdge_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'FlipEdge_24.png' )
    cmd.status_bar_text = 'Flips the dividing edge in the picked triangulated quads.'
    cmd.tooltip = 'Flip Triangulation Tool'
    cmd_flip_triangulation_tool = cmd
    @commands[:flip_triangulation_tool] = cmd
    
    cmd = UI::Command.new( 'Flip Triangulation' )  { self.flip_triangulation }
    cmd.status_bar_text = 'Flips the dividing edge in the selected triangulated quads.'
    cmd.tooltip = 'Flip Triangulation'
    cmd_flip_triangulation = cmd
    @commands[:flip_triangulation] = cmd
    
    cmd = UI::Command.new( 'Triangulate' )  { self.triangulate_selection }
    cmd.small_icon = File.join( PATH_ICONS, 'Triangulate_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Triangulate_24.png' )
    cmd.status_bar_text = 'Triangulates selected quads.'
    cmd.tooltip = 'Triangulate'
    cmd_triangulate_selection = cmd
    @commands[:triangulate] = cmd
    
    cmd = UI::Command.new( 'Remove Triangulation' )  { self.remove_triangulation }
    cmd.small_icon = File.join( PATH_ICONS, 'Detriangulate_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Detriangulate_24.png' )
    cmd.status_bar_text = 'Remove triangulation from selected planar quads.'
    cmd.tooltip = 'Remove Triangulation'
    cmd_remove_triangulation = cmd
    @commands[:remove_triangulation] = cmd
    
    cmd = UI::Command.new( 'Triangulated Mesh to Quads' )  {
      self.convert_connected_mesh_to_quads
    }
    cmd.small_icon = File.join( PATH_ICONS, 'ConvertToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ConvertToQuads_24.png' )
    cmd.status_bar_text = 'Convert triangulated mesh to quads.'
    cmd.tooltip = 'Convert Triangulated Mesh to Quads'
    cmd_convert_connected_mesh_to_quads = cmd
    @commands[:mesh_to_quads] = cmd
    
    cmd = UI::Command.new( 'Blender Quads to QuadFace Quads' )  {
      self.convert_blender_quads_to_sketchup_quads
    }
    cmd.small_icon = File.join( PATH_ICONS, 'BlenderToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'BlenderToQuads_24.png' )
    cmd.status_bar_text = 'Convert Blender imported quads to QuadFace quads.'
    cmd.tooltip = 'Convert Blender Quads to QuadFace Quads'
    cmd_convert_blender_quads_to_sketchup_quads = cmd
    @commands[:blender_to_quads] = cmd
    
    cmd = UI::Command.new( 'Sandbox Quads to QuadFace Quads' )  {
      self.convert_legacy_quadmesh_to_latest
    }
    cmd.small_icon = File.join( PATH_ICONS, 'SandboxToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SandboxToQuads_24.png' )
    cmd.status_bar_text = 'Convert Sandbox Quads to QuadFace Quads.'
    cmd.tooltip = 'Convert Sandbox Quads to QuadFace Quads'
    cmd_convert_legacy_quads = cmd
    @commands[:convert_legacy_quads] = cmd
    
    cmd = UI::Command.new( 'Wireframe to Quads' )  {
      self.wireframe_to_quad_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'WireframeToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'WireframeToQuads_24.png' )
    cmd.status_bar_text = 'Convert a set of edges forming a wireframe to Quads.'
    cmd.tooltip = 'Convert Wireframe to Quads'
    cmd_wireframe_to_quad_tool = cmd
    @commands[:wireframe_quads] = cmd
    
    cmd = UI::Command.new( 'Smooth Quads' )  {
      self.smooth_quad_mesh
    }
    cmd.small_icon = File.join( PATH_ICONS, 'Smooth_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Smooth_24.png' )
    cmd.status_bar_text = 'Smooths the edges of the selected quads.'
    cmd.tooltip = 'Smooth Quads'
    cmd_smooth_quad_mesh = cmd
    @commands[:smooth_quads] = cmd
    
    cmd = UI::Command.new( 'Unsmooth Quads' )  {
      self.unsmooth_quad_mesh
    }
    cmd.small_icon = File.join( PATH_ICONS, 'Unsmooth_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Unsmooth_24.png' )
    cmd.status_bar_text = 'Unsmooths the edges of the selected quads.'
    cmd.tooltip = 'Unsmooth Quads'
    cmd_unsmooth_quad_mesh = cmd
    @commands[:unsmooth_quads] = cmd
    
    cmd = UI::Command.new( 'Make Planar' )  {
      self.make_planar
    }
    cmd.status_bar_text = 'Projects the vertices of selected faces to a best fit plane.'
    cmd.tooltip = 'Make Planar'
    cmd_make_planar = cmd
    @commands[:make_planar] = cmd
    
    cmd = UI::Command.new( 'UV Mapping' )  {
      self.uv_map_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Map_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Map_24.png' )
    cmd.status_bar_text = 'UV maps selected Quads from picked U and V axis.'
    cmd.tooltip = 'UV Mapping Tool'
    cmd_uv_map = cmd
    @commands[:uv_map] = cmd
    
    cmd = UI::Command.new( 'Copy UV Mapping' )  {
      self.uv_copy_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Copy_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Copy_24.png' )
    cmd.status_bar_text = 'Copy UV mapping from selected quad-mesh.'
    cmd.tooltip = 'Copy UV Mapping'
    cmd_uv_copy = cmd
    @commands[:uv_copy] = cmd
    
    cmd = UI::Command.new( 'Paste UV Mapping' )  {
      self.uv_paste_tool
    }
    cmd.set_validation_proc  {
      ( UV_CopyTool.clipboard ) ? MF_ENABLED : MF_GRAYED
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Paste_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Paste_24.png' )
    cmd.status_bar_text = 'Paste UV mapping to selected quad-mesh.'
    cmd.tooltip = 'Paste UV Mapping'
    cmd_uv_paste = cmd
    @commands[:uv_paste] = cmd
    
    cmd = UI::Command.new( 'Unwrap UV Grid' )  {
      self.unwrap_uv_grid_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Unwrap_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Unwrap_24.png' )
    cmd.status_bar_text = 'Unwraps picked UV mapping grid to a flat mesh.'
    cmd.tooltip = 'Unwrap UV Grid'
    cmd_unwrap_uv_grid = cmd
    @commands[:unwrap_uv_grid] = cmd

    cmd = UI::Command.new( 'Line' )   { self.line_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'Line_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Line_24.png' )
    cmd.status_bar_text = 'Draw edges from point to point.'
    cmd.tooltip = 'Line'
    cmd_line = cmd
    @commands[:line_tool] = cmd

    cmd = UI::Command.new( 'OBJ Format' ) { ExporterOBJ.new.prompt }
    cmd.status_bar_text = 'Export model or selection to OBJ format.'
    cmd.tooltip = 'Export to OBJ Format'
    cmd_export_obj = cmd
    @commands[:export_obj] = cmd
    
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
    
    cmd = UI::Command.new( 'About QuadFace Tools…' )  {
      self.show_about_window
    }
    cmd.status_bar_text = 'Display plugin information and related links.'
    cmd.tooltip = 'Display plugin information and related links.'
    cmd_about = cmd
    @commands[:about] = cmd
    
    
    # Menus
    m = TT.menu( 'Tools' ).add_submenu( 'QuadFace Tools' )
    m.add_item( cmd_select )
    m.add_separator
    m.add_item( cmd_selection_grow )
    m.add_item( cmd_selection_shrink )
    m.add_separator
    m.add_item( cmd_select_ring )
    m.add_item( cmd_select_loop )
    m.add_separator
    m.add_item( cmd_offset_loop_tool )
    m.add_separator
    m.add_item( cmd_region_to_loop )
    m.add_item( cmd_loop_to_region )
    m.add_separator
    m.add_item( cmd_select_quads_from_edges )
    m.add_item( cmd_select_bounding_edges )
    m.add_item( cmd_deselect_triangulation )
    m.add_separator
    m.add_item( cmd_smooth_quad_mesh )
    m.add_item( cmd_unsmooth_quad_mesh )
    m.add_separator
    m.add_item( cmd_connect )
    m.add_item( cmd_insert_loops )
    m.add_item( cmd_remove_loops )
    if Settings.read('DebugDisplayOffsetLoopTool', false)
      m.add_item( cmd_offset_loop_tool )
    end
    m.add_separator
    m.add_item( cmd_build_corners )
    m.add_item( cmd_build_ends )
    m.add_separator
    m.add_item( cmd_flip_triangulation_tool )
    m.add_item( cmd_flip_triangulation )
    m.add_item( cmd_triangulate_selection )
    m.add_item( cmd_remove_triangulation )
    m.add_separator
    m.add_item( cmd_make_planar )
    m.add_separator
    m.add_item( cmd_uv_map )
    m.add_item( cmd_uv_copy )
    m.add_item( cmd_uv_paste )
    m.add_item( cmd_unwrap_uv_grid )
    m.add_separator
    m.add_item( cmd_line )
    m.add_separator
    sub_menu = m.add_submenu( 'Convert' )
    sub_menu.add_item( cmd_convert_connected_mesh_to_quads )
    sub_menu.add_separator
    sub_menu.add_item( cmd_wireframe_to_quad_tool )
    sub_menu.add_separator
    sub_menu.add_item( cmd_convert_blender_quads_to_sketchup_quads )
    sub_menu.add_item( cmd_convert_legacy_quads )
    m.add_separator
    sub_menu = m.add_submenu( 'Export' )
    sub_menu.add_item( cmd_export_obj )
    m.add_separator
    sub_menu = m.add_submenu( 'Preferences' )
    sub_menu.add_item( cmd_toggle_context_menu )
    m.add_separator
    m.add_item( cmd_about )
    
    # Context menu
    UI.add_context_menu_handler { |context_menu|
      if @settings[ :context_menu ]
        m = context_menu.add_submenu( 'QuadFace Tools' )
        m.add_item( cmd_selection_grow )
        m.add_item( cmd_selection_shrink )
        m.add_separator
        m.add_item( cmd_select_ring )
        m.add_item( cmd_select_loop )
        m.add_separator
        m.add_item( cmd_region_to_loop )
        m.add_item( cmd_loop_to_region )
        m.add_separator
        m.add_item( cmd_select_quads_from_edges )
        m.add_item( cmd_select_bounding_edges )
        m.add_item( cmd_deselect_triangulation )
        # (i) Loop stepping menu items removed as they are too impractical to
        #     operate via menus which require multiple clicks to trigger.
        m.add_separator
        m.add_item( cmd_smooth_quad_mesh )
        m.add_item( cmd_unsmooth_quad_mesh )
        m.add_separator
        m.add_item( cmd_connect )
        m.add_item( cmd_insert_loops )
        m.add_item( cmd_remove_loops )
        if Settings.read('DebugDisplayOffsetLoopTool', false)
          m.add_item( cmd_offset_loop_tool )
        end
        m.add_separator
        m.add_item( cmd_build_corners )
        m.add_item( cmd_build_ends )
        m.add_separator
        m.add_item( cmd_flip_triangulation_tool )
        m.add_item( cmd_flip_triangulation )
        m.add_item( cmd_triangulate_selection )
        m.add_item( cmd_remove_triangulation )
        m.add_separator
        m.add_item( cmd_make_planar )
        m.add_separator
        m.add_item( cmd_uv_map )
        m.add_item( cmd_uv_copy )
        m.add_item( cmd_uv_paste )
        m.add_item( cmd_unwrap_uv_grid )
        m.add_separator
        m.add_item( cmd_line )
        m.add_separator
        sub_menu = m.add_submenu( 'Convert' )
        sub_menu.add_item( cmd_convert_connected_mesh_to_quads )
        sub_menu.add_separator
        sub_menu.add_item( cmd_wireframe_to_quad_tool )
        sub_menu.add_separator
        sub_menu.add_item( cmd_convert_blender_quads_to_sketchup_quads )
        sub_menu.add_item( cmd_convert_legacy_quads )
        m.add_separator
        sub_menu = m.add_submenu( 'Export' )
        sub_menu.add_item( cmd_export_obj )
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
    toolbar.add_item( cmd_flip_triangulation_tool )
    toolbar.add_item( cmd_triangulate_selection )
    toolbar.add_item( cmd_remove_triangulation )
    toolbar.add_separator
    toolbar.add_item( cmd_build_corners )
    toolbar.add_item( cmd_build_ends )
    toolbar.add_separator
    toolbar.add_item( cmd_convert_connected_mesh_to_quads )
    toolbar.add_separator
    toolbar.add_item( cmd_wireframe_to_quad_tool )
    toolbar.add_item( cmd_convert_legacy_quads )
    toolbar.add_item( cmd_convert_blender_quads_to_sketchup_quads )
    toolbar.add_separator
    toolbar.add_item( cmd_uv_map )
    toolbar.add_item( cmd_uv_copy )
    toolbar.add_item( cmd_uv_paste )
    toolbar.add_item( cmd_unwrap_uv_grid )
    toolbar.add_separator
    toolbar.add_item( cmd_smooth_quad_mesh )
    toolbar.add_item( cmd_unsmooth_quad_mesh )
    toolbar.add_separator
    toolbar.add_item( cmd_insert_loops )
    toolbar.add_item( cmd_remove_loops )
    toolbar.add_item( cmd_connect )
    if Settings.read('DebugDisplayOffsetLoopTool', false)
      toolbar.add_item( cmd_offset_loop_tool )
    end
    toolbar.add_separator
    toolbar.add_item( cmd_line )
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
  def self.flip_edge_tool
    Sketchup.active_model.select_tool( FlipEdgeTool.new )
  end
  
  
  # @since 0.4.0
  def self.uv_map_tool
    model = Sketchup.active_model
    material = model.materials.current
    if material.nil? || material.texture.nil?
      UI.messagebox( 'No textured material selected.' )
      return false
    end
    unless TT::Material.in_model?( material, model )
      UI.messagebox( 'Selected material is not in the model. Apply it to something in the model first.' )
      return false
    end
    model.select_tool( UV_MapTool.new )
    true
  end
  
  
  # @since 0.4.0
  def self.uv_copy_tool
    Sketchup.active_model.select_tool( UV_CopyTool.new )
  end
  
  # @since 0.4.0
  def self.uv_paste_tool
    Sketchup.active_model.select_tool( UV_PasteTool.new )
  end
  
  
  # @since 0.4.0
  def self.unwrap_uv_grid_tool
    Sketchup.active_model.select_tool( UV_UnwrapGridTool.new )
  end
  
  
  # @since 0.7.0
  def self.wireframe_to_quad_tool
    Sketchup.active_model.select_tool( WireframeToQuadsTool.new )
  end

  # @since 0.8.0
  def self.line_tool
    Sketchup.active_model.select_tool( LineTool.new )
  end
  
  
  # @since 0.5.0
  def self.show_about_window
    # (!) Add links to download page, SCF and donation page when TT_Lib2
    #     supports richer controls.
    
    # This attemps to center the window on the screen, but is not 100% correct
    # as it assumes the SU window is maximized. There is currently no method to
    # get the position of the SketchUp window, so if it's on a different monitor
    # or not maximized it'll not position as expected. But should be an ok
    # default. Could make use of Win32 API under Windows.
    view = Sketchup.active_model.active_view
    width = 280
    height = 180
    left = ( view.vpwidth / 2 ) - ( width / 2 )
    top = ( view.vpheight / 2 ) - ( height / 2 )
    props = {
      :title => 'About QuadFace Tools',
      :left => left,
      :top => top,
      :width => width,
      :height => height,
      :resizable => false
    }
    window = TT::GUI::Window.new( props )
    window.theme = TT::GUI::Window::THEME_GRAPHITE
    window.set_position( left, top )
    
    lblTitle = TT::GUI::Label.new( "#{PLUGIN_NAME}" )
    lblTitle.top = 5
    lblTitle.left = 10
    lblTitle.font_size = '200%'
    window.add_control( lblTitle )
    
    lblVersion = TT::GUI::Label.new( "(#{PLUGIN_VERSION})" )
    lblVersion.top = 17
    lblVersion.left = 170
    window.add_control( lblVersion )
    
    lblDescription = TT::GUI::Label.new( "#{self.extension.description}" )
    lblDescription.top = 50
    lblDescription.left = 20
    window.add_control( lblDescription )
    
    lblWebsite = TT::GUI::Label.new( "Visit Website" )
    lblWebsite.url = 'https://bitbucket.org/thomthom/quadface-tools/'
    lblWebsite.top = 80
    lblWebsite.left = 20
    window.add_control( lblWebsite )
    
    lblCookieware = TT::GUI::Label.new( 'This plugin is Cookieware - Feed the author!' )
    lblCookieware.url = 'http://www.thomthom.net/software/sketchup/cookieware/'
    lblCookieware.top = 100
    lblCookieware.left = 20
    window.add_control( lblCookieware )
    
    lblCopyright = TT::GUI::Label.new( "#{self.extension.copyright}" )
    lblCopyright.bottom = 10
    lblCopyright.left = 10
    window.add_control( lblCopyright )
    
    btnClose = TT::GUI::Button.new( 'Close' ) { |control|
      control.window.close
    }
    btnClose.size( 75, 23 )
    btnClose.right = 5
    btnClose.bottom = 5
    window.add_control( btnClose )
    
    window.show_window
    window
  end
  
  
  # @since 0.7.0
  def self.build_ends
    t = Time.now
    model = Sketchup.active_model
    entities = model.active_entities
    provider = EntitiesProvider.new
    TT::Model.start_operation( 'Build Ends' )
    for edge in model.selection.to_a
      # Find edges that separate a quad and a hexagon.
      # The hexagon should really be a quad-ish shape where one of the sides
      # is made up of three edges. The source edge must be the middle of these.
      next unless edge.valid?
      next unless edge.is_a?( Sketchup::Edge )
      next unless edge.faces.size == 2
      next if QuadFace.divider_props?( edge )
      faces = Surface.get( edge.faces )
      hexagon = faces.find { |f| f.vertices.size == 6 }
      quad1 = faces.find { |f| f.vertices.size == 4 }
      next unless hexagon && quad1
      # The quad needs two adjacent quads that share one of the vertices of the
      # source edge.
      e1 = quad1.next_edge( edge )
      e2 = quad1.prev_edge( edge )
      faces = e1.faces + e2.faces - quad1.faces
      faces = Surface.get( faces )
      next unless faces.all? { |face| face.vertices.size == 4 }
      # Recreate four quads in place of the hexagon.
      #   Copy the soft, smooth and hidden properties of the source edge to the
      #   new edges.
      soft_prop = edge.soft?
      smooth_prop = edge.smooth?
      hidden_prop = edge.hidden?
      # Cache materials for later transfer.
      material      = hexagon.material
      back_material = hexagon.back_material
      #   Get the positions of the source edge in the correct order.
      next_edge = hexagon.next_edge( edge )
      vc = TT::Edges.common_vertex( edge, next_edge )
      loop = hexagon.vertices
      if vc == edge.start
        pt1 = edge.start.position
        pt2 = edge.end.position
        i = loop.index( edge.start )
      else
        pt1 = edge.end.position
        pt2 = edge.start.position
        i = loop.index( edge.end )
      end
      #   Get the positions of the side edges
      e1pt1 = loop[ ( i + 1 ) % 6 ].position
      e1pt2 = loop[ ( i + 2 ) % 6 ].position
      e2pt1 = loop[ ( i - 2 ) % 6 ].position
      e2pt2 = loop[ ( i - 3 ) % 6 ].position
      #   Calculate internal point
      v1 = e1pt1.vector_to( e1pt2 )
      v2 = e2pt1.vector_to( e2pt2 )
      v3 = Geom.linear_combination( 0.75, v1, 0.25, v2 )
      v4 = Geom.linear_combination( 0.25, v1, 0.75, v2 )
      mpt1 = e1pt1.offset( v1, v1.length / 2 )
      mpt2 = e2pt1.offset( v2, v2.length / 2 )
      m_line = [ mpt1, mpt2 ]
      i1pts = Geom.closest_points( m_line, [ pt1, v3 ] )
      i2pts = Geom.closest_points( m_line, [ pt2, v4 ] )
      ipt1 = TT::Geom3d.average_point( i1pts )
      ipt2 = TT::Geom3d.average_point( i2pts )
      #   Erase old geometry.
      hexagon.erase!
      #   Create new geometry.
      new_edges = []
      new_edges << entities.add_line( pt1, ipt1 )
      new_edges << entities.add_line( pt2, ipt2 )
      new_edges << entities.add_line( ipt1, ipt2 )
      new_edges << entities.add_line( ipt1, e1pt2 )
      new_edges << entities.add_line( ipt2, e2pt2 )
      new_edges.each { |e|
        e.soft = soft_prop
        e.smooth = smooth_prop
        e.hidden = hidden_prop
      }
      new_faces = []
      new_faces << provider.add_quad( pt1, pt2, ipt2, ipt1 )
      new_faces << provider.add_quad( e1pt1, e1pt2, ipt1, pt1 )
      new_faces << provider.add_quad( e2pt1, e2pt2, ipt2, pt2 )
      new_faces << provider.add_quad( e1pt2, e2pt2, ipt2, ipt1 )
      # Transfer materials.
      for face in new_faces
        face.material      = material
        face.back_material = back_material
      end
      # (!) Transfer UV mapping.
    end
    model.commit_operation
    TT.debug "self.build_ends: #{Time.now - t}"
  end
  
  
  # @since 0.7.0
  def self.build_corners
    t = Time.now
    model = Sketchup.active_model
    entities = model.active_entities
    provider = EntitiesProvider.new
    TT::Model.start_operation( 'Build Corners' )
    for edge in model.selection.to_a
      # Find edges that separate a triangle and pentagon.
      next unless edge.valid?
      next unless edge.is_a?( Sketchup::Edge )
      next unless edge.faces.size == 2
      next if QuadFace.divider_props?( edge )
      faces = Surface.get( edge.faces )
      triangle = faces.find { |f| f.vertices.size == 3 }
      pentagon = faces.find { |f| f.vertices.size == 5 }
      next unless triangle && pentagon
      # Copy the soft, smooth and hidden properties of the source edge to the
      # new edges.
      soft_prop   = edge.soft?
      smooth_prop = edge.smooth?
      hidden_prop = edge.hidden?
      # Copy the material to the new faces.
      tri_material      = triangle.material
      tri_back_material = triangle.back_material
      pen_material      = pentagon.material
      pen_back_material = pentagon.back_material
      # Find the edges 1 edge away from the source edge.
      loop = pentagon.outer_loop
      index = loop.index( edge )
      i1 = ( index + 2 ) % 5
      i2 = ( index - 2 ) % 5
      e1 = loop[ i1 ]
      e2 = loop[ i2 ]
      # Find the third vertex in the triangle, the one not used by the source
      # edge.
      tri_pt = ( triangle.vertices - edge.vertices )[0].position
      # Project each vertex of the source edge to the mid point of the adjacent
      # edges. Find the average point between them and use that as the
      # intersecting point for the new quads.
      #
      #   Get the positions of the source edge in the correct order.
      next_i = ( index + 1 ) % 5
      next_edge = loop[ next_i ]
      vc = TT::Edges.common_vertex( edge, next_edge )
      if vc == edge.start
        pt1 = edge.end.position
        pt2 = edge.start.position
      else
        pt1 = edge.start.position
        pt2 = edge.end.position
      end
      #   Get the shared vertex of the opposite edges.
      shared_vertex = TT::Edges.common_vertex( e1, e2 )
      pt3 = shared_vertex.position
      #   Get the positions of the opposite edges in the correct order.
      e1_vertex = e1.other_vertex( shared_vertex )
      e2_vertex = e2.other_vertex( shared_vertex )
      pts1 = [ pt3, e1_vertex.position ]
      pts2 = [ pt3, e2_vertex.position ]
      #   Calculate the intersecting position.
      m1 = TT::Geom3d.average_point( pts1 )
      m2 = TT::Geom3d.average_point( pts2 )
      pts = Geom.closest_points( [pt1,m1], [pt2,m2] )
      intersect = TT::Geom3d.average_point( pts )
      # Erase old geometry.
      triangle.erase!
      pentagon.erase!
      edge.erase!
      # Create new geometry.
      new_edges = []
      new_edges << entities.add_line( pt1, intersect )
      new_edges << entities.add_line( pt2, intersect )
      new_edges << entities.add_line( pt3, intersect )
      new_edges.each { |e|
        e.soft = soft_prop
        e.smooth = smooth_prop
        e.hidden = hidden_prop
      }
      f1 = provider.add_quad( pts2[1], pts2[0], intersect, pt1 )
      f2 = provider.add_quad( pts1[1], pts1[0], intersect, pt2 )
      f3 = provider.add_quad( tri_pt, pt1, intersect, pt2 )
      # Transfer materials.
      f1.material      = pen_material
      f1.back_material = pen_back_material
      f2.material      = pen_material
      f2.back_material = pen_back_material
      f3.material      = tri_material
      f3.back_material = tri_back_material
      # (!) Transfer UV mapping.
    end
    model.commit_operation
    TT.debug "self.build_corners: #{Time.now - t}"
  end
  
  
  # @since 0.5.0
  def self.flip_triangulation
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    TT::Model.start_operation( 'Flip Triangulation' )
    new_faces = []
    for quad in selection
      next unless quad.is_a?( QuadFace )
      quad.flip_edge
      new_faces.concat( quad.faces )
    end
    model.commit_operation
    model.selection.add( new_faces )
    TT.debug "self.flip_triangulation: #{Time.now - t}"
  end
  
  
  # @since 0.4.0
  def self.deselect_triangulation
    model = Sketchup.active_model
    selection = model.selection
    edges = selection.select { |e| QuadFace.dividing_edge?( e ) }
    selection.remove( edges )
  end
  
  
  # @since 0.4.0
  def self.select_bounding_edges
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    new_selection = []
    for face in selection
      if face.is_a?( QuadFace )
        new_selection.concat( face.edges + face.faces )
      elsif face.is_a?( Sketchup::Face )
        new_selection.concat( face.edges )
      end
    end
    # Select
    model.selection.add( new_selection )
    TT.debug "self.select_bounding_edges: #{Time.now - t}"
  end
  
  
  # @since 0.4.0
  def self.select_quads_from_edges
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    entities = EntitiesProvider.new( selection )
    new_selection = EntitiesProvider.new
    # Find quads with two or more edges selected
    for entity in entities.edges
      next if QuadFace.dividing_edge?( entity )
      for quad in entities.connected_quads( entity )
        if quad.edges.select { |e| entities.include?( e ) }.size > 1
          new_selection << quad
        end
      end
    end
    # Select
    selection.add( new_selection.native_entities )
    TT.debug "self.select_quads_from_edges: #{Time.now - t}"
  end
  
  
  # @since 0.3.0
  def self.insert_loops
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    entities = EntitiesProvider.new
    # Find Edge Rings in Selection
    for entity in selection.edges
      next if QuadFace.dividing_edge?( entity )
      next if entities.include?( entity )
      entities << selection.find_edge_ring( entity )
    end
    # Edge Connect
    TT::Model.start_operation( 'Insert Loops' )
    edge_connect = EdgeConnect.new( entities.to_a )
    edges = edge_connect.connect!
    model.commit_operation
    # Select
    model.selection.clear
    model.selection.add( edges )
    TT.debug "self.insert_loops: #{Time.now - t}"
  end
  
  
  # @since 0.3.0
  def self.remove_loops
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    provider = EntitiesProvider.new( selection )
    # Proccess each loop
    TT::Model.start_operation( 'Remove Loops' )
    stack = selection.to_a
    until stack.empty?
      entity = stack.shift
      next unless entity.valid?
      next unless entity.is_a?( Sketchup::Edge )
      next if QuadFace.dividing_edge?( entity )
      loop = provider.find_edge_loop( entity )
      stack -= loop
      vertices = {}
      # Make loop edges planar between neighbour faces.
      for edge in loop
        quads = provider.get( edge.faces )
        next unless quads.all? { |quad| quad.is_a?( QuadFace ) }
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
      uv_mapping = []
      for edge in loop
        quads = provider.get( edge.faces )
        next unless quads.all? { |quad| quad.is_a?( QuadFace ) }
        # Find the vertices of the merged face.
        q1, q2 = quads
        e1 = q1.opposite_edge( edge )
        e2 = q2.opposite_edge( edge )
        pts = q1.edge_positions( e1 ) + q2.edge_positions( e2 )
        # Remember UV mapping
        new_quad = {}
        new_quad[ :vertices ] = q1.vertices + q2.vertices
        # > Test material properties
        q1_textured = q1.material && q1.material.texture
        q1_textured_back = q1.back_material && q1.back_material.texture
        q2_textured = q2.material && q2.material.texture
        q2_textured_back = q2.back_material && q2.back_material.texture
        # > Pick material to use
        if q1_textured == q2_textured
          # Prefer material from the larger face.
          front_material = ( q1.area > q2.area ) ? q1.material : q2.material
        else
          # If one is is not textured we cannot combine the UV mapping. Then
          # the plain material is chosen.
          front_material = ( q1_textured ) ? q2.material : q1.material
        end
        if q1_textured_back == q2_textured_back
          back_material = ( q1.area > q2.area ) ? q1.back_material : q2.back_material
        else
          back_material = ( q1_textured_back ) ? q2.back_material : q1.back_material
        end
        new_quad[ :front_material ] = front_material
        new_quad[ :back_material ] = back_material
        # > Sample UV Mapping
        front_textured = q1_textured && q2_textured
        back_textured = q1_textured_back && q2_textured_back
        if front_textured
          uv1 = q1.uv_get
          uv2 = q2.uv_get
          uv_new = {}
          for vertex, uv in uv1
            next if edge.vertices.include?( vertex )
            uv_new[ vertex ] = uv
          end
          for vertex, uv in uv2
            next if edge.vertices.include?( vertex )
            uv_new[ vertex ] = uv
          end
          new_quad[ :uv_front ] = uv_new
        end
        if back_textured
          uv1 = q1.uv_get
          uv2 = q2.uv_get
          uv_new = {}
          for vertex, uv in uv1
            next if edge.vertices.include?( vertex )
            uv_new[ vertex ] = uv
          end
          for vertex, uv in uv2
            next if edge.vertices.include?( vertex )
            uv_new[ vertex ] = uv
          end
          new_quad[ :uv_back ] = uv_new
        end
        # Mark edge for deletion.
        erase_edges << edge
        # If the connected quads are triangulated or the merged face is not
        # planar, erase the faces and re-generate new quad.
        planar = TT::Geom3d.planar_points?( pts )
        triangulated = quads.any? { |quad| quad.triangulated? }
        if !planar || triangulated
          erase_faces.concat( q1.faces + q2.faces )
          new_quads << pts
          new_quad[ :points ] = pts
        end
        uv_mapping << new_quad
      end
      # Reshape and merge the entities.
      active_entities = model.active_entities
      active_entities.erase_entities( erase_faces )
      active_entities.transform_by_vectors( vertex_entities, vectors )
      active_entities.erase_entities( erase_edges )
      # Rebuild triangulated and non-planar quads.
      mapped_quads = []
      for points in new_quads
        quad = provider.add_quad( points )
        # Restore UV mapping
        for data in uv_mapping
          next unless data[ :points ] == points
          mapped_quads << [ quad, data ]
        end
      end
      # Find the remaining quads where the dividing edge between coplanar faces
      # where removed.
      for data in uv_mapping
        next unless data[ :faces ]
        vertices = data[ :vertices ].select { |v| v.valid? }
        quad = QuadFace.from_vertices( vertices )
        next unless quad
        mapped_quads << [ quad, data ]
      end
      # Restore UV mapping
      for quad, data in mapped_quads
        if data[ :uv_front ]
          quad.uv_set( data[ :front_material ], data[ :uv_front ] )
        else
          quad.material = data[ :front_material ]
        end
        if data[ :uv_back ]
          quad.uv_set( data[ :back_material ], data[ :uv_back ], false )
        else
          quad.back_material = data[ :back_material ]
        end
      end
    end
    model.commit_operation
    TT.debug "self.remove_loops: #{Time.now - t}"
  end
  
  
  # Ensures that all quad faces in the current selection is triangulated. This
  # prevents SketchUp's auto-fold feature to break the quad face when it's
  # transformed such that it becomes non-planar.
  #
  # @since 0.1.0
  def self.triangulate_selection
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    new_selection = []
    TT::Model.start_operation( 'Triangulate Quads' )
    for quadface in selection
      next unless quadface.is_a?( QuadFace )
      quadface.triangulate!
      new_selection.concat( quadface.faces )
    end
    model.commit_operation
    model.selection.add( new_selection )
    TT.debug "self.triangulate_selection: #{Time.now - t}"
  end
  
  
  # Converts selected planar triangualted quads into native quads.
  #
  # @since 0.2.0
  def self.remove_triangulation
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    new_selection = []
    TT::Model.start_operation( 'Remove Triangulation' )
    for quadface in selection
      next unless quadface.is_a?( QuadFace )
      next unless quadface.planar?
      quadface.detriangulate!
      new_selection.concat( quadface.faces )
    end
    model.commit_operation
    model.selection.add( new_selection )
    TT.debug "self.remove_triangulation: #{Time.now - t}"
  rescue
    model.abort_operation
    raise
  end
  
  
  # Smooths and hides the edges of selected quads.
  #
  # @since 0.2.0
  def self.smooth_quad_mesh
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    entities = ( selection.empty? ) ? model.active_entities : selection
    TT::Model.start_operation( 'Smooth Quads' )
    self.smooth_quads( entities )
    model.commit_operation
    TT.debug "self.smooth_quad_mesh: #{Time.now - t}"
  end
  
  
  # @param [Enumerable<Sketchup::Entity>] entities
  #
  # @return [Nil]
  # @since 0.5.0
  def self.smooth_quads( entities )
    entities = EntitiesProvider.new( entities )
    for entity in entities
      if TT::Instance.is?( entity )
        definition = TT::Instance.definition( entity )
        self.smooth_quads( definition.entities )
      elsif entity.is_a?( QuadFace )
        for edge in entity.edges
          QuadFace.smooth_edge( edge )
        end
      end
    end
    nil
  end
  
  
  # Unmooths and unhides the edges of selected quads.
  #
  # @since 0.2.0
  def self.unsmooth_quad_mesh
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    entities = ( selection.empty? ) ? model.active_entities : selection
    TT::Model.start_operation( 'Unsmooth Quads' )
    self.unsmooth_quads( entities )
    model.commit_operation
    TT.debug "self.unsmooth_quad_mesh: #{Time.now - t}"
  end
  
  
  # @param [Enumerable<Sketchup::Entity>] entities
  #
  # @return [Nil]
  # @since 0.5.0
  def self.unsmooth_quads( entities )
    entities = EntitiesProvider.new( entities )
    for entity in entities
      if TT::Instance.is?( entity )
        definition = TT::Instance.definition( entity )
        self.unsmooth_quads( definition.entities )
      elsif entity.is_a?( QuadFace )
        for edge in entity.edges
          QuadFace.unsmooth_edge( edge )
        end
      end
    end
    nil
  end
  
  
  # Project the selected entities to a best fit plane.
  #
  # @since 0.2.0
  def self.make_planar
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    provider = EntitiesProvider.new
    vertices = []
    for face in selection.faces
      vertices << face.vertices
      provider << provider.get( face ) # (?) Improve EntitiesProvider?
    end
    vertices.flatten!
    vertices.uniq!
    return false if vertices.empty?
    TT::Model.start_operation( 'Make Planar' )
    # Triangulate connected quads to ensure they are not broken.
    for vertex in vertices
      for quad in provider.connected_quads( vertex )
        next if selection.include?( quad )
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
    model.selection.add( provider.native_entities )
    TT.debug "self.make_planar: #{Time.now - t}"
  rescue
    model.abort_operation
    raise
  end
  
  
  # In QuadFace 0.3 and older a quad was defined as:
  # * Native quad
  # * Two triangles with a soft dividing edge and non-soft edges.
  #
  # In QuadFace 0.4 the definition was updated to:
  # * Native quad
  # * Two triangles with smooth + soft + hidden divider. Border edges can have
  #   any of the properties as long as they don't use them all at the same time.
  #
  # In QuadFace 0.6 the definition was updated to:
  # * Native quad
  # * Two triangles with diogonal poperties:
  #     smooth = true
  #     soft =  true
  #     cast shadows = false.
  #   Border edges can have any of the properties as long as they don't use them
  #   all at the same time.
  #   This change was made because the Hidden property is modified per Scene
  #   and will ruin the definition of a Quad when you have a model with scenes.
  #   The benefit is that now the native smooth tools can be used without
  #   breaking the QuadFace and outline styles renders fine without caps in the
  #   outline profile which the Hidden property caused.
  #
  # @since 0.6.0
  def self.convert_legacy_quadmesh_to_latest
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    entities = ( selection.empty? ) ? model.active_entities : selection
    TT::Model.start_operation( 'Convert Sandbox Quads' )
    self.convert_legacy_to_latest( entities )
    model.commit_operation
    TT.debug "self.convert_legacy_quadmesh_to_latest: #{Time.now - t}"
  end
  
  
  # @param [Enumerable<Sketchup::Entity>] entities
  #
  # @return [Nil]
  # @since 0.6.0
  def self.convert_legacy_to_latest( entities )
    for entity in entities
      if TT::Instance.is?( entity )
        definition = TT::Instance.definition( entity )
        self.convert_legacy_to_latest( definition.entities )
      end
      # Only triangualted quads needs converting.
      next unless entity.is_a?( Sketchup::Face )
      next unless entity.vertices.size == 3
      # In converting both R1 and R2 the R2 definition is tested first because
      # the divider property is more restrictive.
      convert_r1 = false
      # R2 Quads ( 0.4 - 0.5 )
      diagonals = entity.edges.select { |e| e.soft? && e.smooth? && e.hidden? }
      if diagonals.size != 1
        # R1 Quads ( 0.1 - 0.3 ) & Sandbox Quads
        diagonals = entity.edges.select { |e| e.soft? && e.smooth? }
        convert_r1 = true
      end
      # There should only be one edge with diogonal properties in the triangle.
      next unless diagonals.size == 1
      diagonal = diagonals[0]
      # The diogonal should be connected to only two triangles.
      next unless diagonal.faces.size == 2
      other_face = ( diagonal.faces - [ entity ] )[0]
      next unless other_face.edges.size == 3
      # The other triangle must be verified to only have one edge with diogonal
      # properties.
      if convert_r1
        diagonals = entity.edges.select { |e| e.soft? && e.smooth? }
      else
        diagonals = entity.edges.select { |e| e.soft? && e.smooth? && e.hidden? }
      end
      next unless diagonals.size == 1
      # The edge has been verified and can be upgraded.
      diagonal.hidden = false # Clean up the old R2 property.
      QuadFace.set_divider_props( diagonal )
    end
    nil
  end
  
  
  # DAE models from Blender with quads imports into SketchUp as triangles with
  # a hidden dividing edge instead of a soft one. This routine converts these
  # quads into SketchUp quads.
  #
  # @since 0.2.0
  def self.convert_blender_quads_to_sketchup_quads
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    entities = ( selection.empty? ) ? model.active_entities : selection
    TT::Model.start_operation( 'Convert Blender Quads' )
      self.convert_blender_quads( entities )
    model.commit_operation
    TT.debug "self.convert_blender_quads_to_sketchup_quads: #{Time.now - t}"
  end
  
  
  # Recursivly converts two sets of triangles sharing a hidden edge with visible
  # edges into QuadFace compatible quads.
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
      QuadFace.set_divider_props( entity )
    end
  end
  
  
  # Converts selected entities into edge loops.
  #
  # @see http://wiki.blender.org/index.php/Template:Release_Notes/2.42/Mesh/Editing
  #
  # @since 0.2.0
  def self.region_to_loop
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    entities = EntitiesProvider.new( selection )
    # Collect faces in selection.
    region = EntitiesProvider.new
    for entity in entities
      if entity.is_a?( Sketchup::Face ) || entity.is_a?( QuadFace )
        region << entities.get( entity )
      elsif entity.is_a?( Sketchup::Edge )
        region << entities.get( entity.faces )
      end
    end
    # Find edges bordering the faces.
    edges = []
    for face in region
      for edge in face.edges
        if edge.faces.size == 1
          edges << edge
        elsif !edge.faces.all? { |f| region.include?( f ) }
          edges << edge
        end
      end
    end
    # Select loops.
    selection.clear
    selection.add( edges )
    TT.debug "self.region_to_loop: #{Time.now - t}"
  end
  
  
  # @since 0.7.0
  def self.loop_to_region
    t = Time.now
    model = Sketchup.active_model
    selection = model.selection
    selected = selection.to_a
    entities = EntitiesProvider.new( selection )
    # Find Loop and one edge
    # Find connected faces of either side of loop
    # Find which collection the lone edge belongs to - select it.
    loop_edges = []
    marker = nil
    # Find marker(s)
    for edge in entities
      next unless edge.is_a?( Sketchup::Edge )
      connected = edge.vertices.map { |v| v.edges }.flatten.uniq - [edge]
      sel = selected & connected
      if sel.empty?
        if marker
          UI.messagebox( 'Selection must contain only one loop and one marker.' )
          return nil
        else
          marker = edge
        end
      else
        loop_edges << edge
      end
    end
    # (!) Edges can not have more than two faces connected.
    # Find loop
    sorted = TT::Edges.sort( loop_edges )
    if sorted.nil?
      UI.messagebox( 'No loop found in selection.' )
      return nil
    end
    loop = TT::Edges.sort_vertices( sorted )
    if loop.first != loop.last
      UI.messagebox( 'No closed loop found in selection.' )
      return nil
    end
    # Find region from marker
    #   (!) EntitiesProvider.get doesn't return the same QuadFace unless #add
    #       has been used to add the enitites previously.
    processed = EntitiesProvider.new
    processed.add( marker.faces )
    
    stack = processed.get( marker.faces ) # Assume two faces.
    region = EntitiesProvider.new
    
    until stack.empty?
      face = stack.shift
      
      next if region.include?( face )
      region.add( face )
      # Find next candidates.
      for e in face.edges
        next if sorted.include?( e )
        
        processed.add( e.faces )
        faces = processed.get( e.faces )
        
        for f in faces
          stack << f unless region.include?( f )
        end
      end
    end
    selection.add( region.native_entities )
    TT.debug "self.loop_to_region: #{Time.now - t}"
  end
  
  
  # Selects rings based on the selected entities.
  #
  # @param [Boolean] step
  #
  # @since 0.1.0
  def self.select_rings( step = false )
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    new_selection = EntitiesProvider.new
    for entity in selection
      if entity.is_a?( Sketchup::Edge )
        next if QuadFace.dividing_edge?( entity )
        next if !step && new_selection.include?( entity )
        new_selection << selection.find_edge_ring( entity, step )
      elsif entity.is_a?( QuadFace ) && !step
        next if new_selection.include?( entity )
        selected = entity.connected_quads( selection )
        if selected.size == 1
          edge1 = entity.common_edge( selected[0] )
          edge = entity.next_edge( edge1 )
        elsif selected.size == 2
          edge1 = entity.common_edge( selected[0] )
          edge2 = entity.common_edge( selected[1] )
          next unless entity.opposite_edge( edge1 ) == edge2
          edge = entity.next_edge( edge1 )
        else
          next
        end
        new_selection << selection.find_face_ring( entity, edge )
      end
    end
    # Select
    model.selection.add( new_selection.native_entities )
    TT.debug "self.select_rings: #{Time.now - t}"
  end
  
  
  # Shrink ring loops.
  #
  # @since 0.1.0
  def self.shrink_rings
    t = Time.now
    model = Sketchup.active_model
    selection = EntitiesProvider.new( model.selection )
    entities = []
    for entity in selection
      next unless entity.is_a?( Sketchup::Edge )
      next if QuadFace.dividing_edge?( entity )
      next unless entity.faces.size == 2
      # Check neighbouring faces if their opposite edges are selected.
      # Deselect any edge where not all opposite edges are selected.
      faces = selection[ entity.faces ]
      #unless entity.faces.all? { |face|
      unless faces.all? { |face|
        if face.is_a?( QuadFace )
          edge = face.opposite_edge( entity )
          selection.include?( edge )
        else
          false
        end
      }
        entities << entity
      end
    end
    # Select
    model.selection.remove( entities )
    TT.debug "self.shrink_rings: #{Time.now - t}"
  end
  
  
  # Selects loops based on the selected entities.
  #
  # @param [Boolean] step
  #
  # @since 0.1.0
  def self.select_loops( step = false )
    t = Time.now
    selection = Sketchup.active_model.selection
    provider = EntitiesProvider.new( selection )
    entities = EntitiesProvider.new
    for entity in provider
      if entity.is_a?( Sketchup::Edge )
        next if QuadFace.dividing_edge?( entity )
        next if !step && entities.include?( entity )
        entities << provider.find_edge_loop( entity, step )
      elsif entity.is_a?( QuadFace )
        # Added in 0.5.0
        next if !step && entities.include?( entity )
        # Check if any of the bordering quads also are selected.
        # Use to determine direction. If none, traverse in all directions.
        connected = entity.connected_quads( selection )
        if connected.empty?
          if step
            entities << entity.connected_quads
          else
            connected = entity.connected_quads
          end
        end
        # Select loops.
        for quad in connected
          entities << provider.find_face_loop( entity, quad, step )
        end
      end
    end
    # Select
    selection.add( entities.native_entities )
    TT.debug "self.select_loops: #{Time.now - t}"
  end
  
  
  # Shrink ring loops.
  #
  # @since 0.1.0
  def self.shrink_loops
    t = Time.now
    selection = Sketchup.active_model.selection
    provider = EntitiesProvider.new( selection )
    selected = selection.to_a
    entities = EntitiesProvider.new
    for entity in provider
      if entity.is_a?( Sketchup::Edge )
        next if QuadFace.dividing_edge?( entity )
        next unless entity.faces.size == 2
        # Check next edges in loop, if they are not all selected, deselect the
        # edge.
        edges = provider.find_edge_loop( entity, true )
        unless ( edges & selected ).size == edges.size
          entities << entity
        end
      elsif entity.is_a?( QuadFace )
        # Added in 0.5.0
        next unless QuadFace.is?( entity )
        selected_quads = entity.connected_quads( selection )
        next unless selected_quads.size == 1
        # Deselect edge quads.
        for quad in selected_quads
          edge1 = entity.common_edge( quad )
          edge2 = entity.opposite_edge( edge1 )
          next_quad = entity.next_quad( edge2 )
          if next_quad
            next if next_quad.faces.any? { |f| selection.include?( f ) }
          end
          entities << entity.faces
          break
        end
      end
    end
    # Select
    selection.remove( entities.native_entities )
    TT.debug "self.shrink_loops: #{Time.now - t}"
  end


  def self.offset_loop_tool
    model = Sketchup.active_model
    model.select_tool(OffsetTool.new)
    nil
  end
  
  
  # Extend the selection by one entity from the current selection set.
  #
  # @since 0.1.0
  def self.selection_grow
    t = Time.now
    selection = Sketchup.active_model.selection
    entities = EntitiesProvider.new( selection )
    new_selection = []
    for entity in entities
      if entity.is_a?( Sketchup::Edge )
        for vertex in entity.vertices
          edges = vertex.edges.select { |e| !QuadFace.dividing_edge?( e ) }
          new_selection.concat( edges )
        end
      elsif entity.respond_to?( :edges )
        for edge in entity.edges
          for face in edge.faces
            e = entities.get( face )
            if e.is_a?( QuadFace )
              new_selection.concat( e.faces )
            else
              new_selection << e
            end
          end
        end # for edge in face.edges
      end # if entity.is_a?
    end # for entity
    selection.add( new_selection )
    TT.debug "self.selection_grow: #{Time.now - t}"
  end
  
  
  # Shrinks the selection by one entity from the current selection set.
  #
  # @since 0.1.0
  def self.selection_shrink
    t = Time.now
    selection = Sketchup.active_model.selection
    entities = EntitiesProvider.new( selection )
    new_selection = []
    for entity in entities
      if entity.is_a?( Sketchup::Edge )
        unless entity.vertices.all? { |vertex|
          edges = vertex.edges.select { |e| !QuadFace.dividing_edge?( e ) }
          edges.all? { |edge| entities.include?( edge ) }
        }
          new_selection << entity
        end
      elsif entity.is_a?( Sketchup::Face ) || entity.is_a?( QuadFace )
        unless entity.edges.all? { |edge|
          edge.faces.all? { |face|
            entities.include?( face )
          }
        }
          if entity.is_a?( QuadFace )
            new_selection.concat( entity.faces )
          else
            new_selection << entity
          end
        end
      end # if entity.is_a?
    end # for entity
    # Update selection
    selection.remove( new_selection )
    TT.debug "self.selection_shrink: #{Time.now - t}"
  end
  

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
    #load __FILE__
    # Supporting files
    x = Dir.glob( File.join(PATH, '**/*.{rb,rbs}') ).each { |file|
      load file
    }
    x.length
  ensure
    $VERBOSE = original_verbose
  end
  
end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------