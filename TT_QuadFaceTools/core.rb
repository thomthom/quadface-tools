#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?( '2.6.0', 'QuadFace Tools' )

#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  
  ### PREFERENCES ### ----------------------------------------------------------
  
  @settings = TT::Settings.new( PLUGIN_ID )
  # UI
  @settings.set_default( :context_menu, false )
  # Select Tool
  @settings.set_default( :ui_show_poles, false )
  # Connect Edge
  @settings.set_default( :connect_splits, 1 )
  @settings.set_default( :connect_pinch, 0 )
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
    
    cmd = UI::Command.new( 'Select Quads from Edges' )  {
      self.select_quads_from_edges
    }
    cmd.status_bar_text = 'Selects quads with two or more edges selected.'
    cmd.tooltip = 'Selects quads with two or more edges selected'
    cmd_select_quads_from_edges = cmd
    @commands[:select_quads_from_edges] = cmd
    
    cmd = UI::Command.new( 'Select Bounding Edges' )  {
      self.select_bounding_edges
    }
    cmd.status_bar_text = 'Selects all edges that bounds a face.'
    cmd.tooltip = 'Selects all edges that bounds a face'
    cmd_select_bounding_edges = cmd
    @commands[:select_bounding_edges] = cmd
    
    cmd = UI::Command.new( 'Deselect Triangulation' )  {
      self.deselect_triangulation
    }
    cmd.status_bar_text = 'Deselects all dividing edges in triangulated quads.'
    cmd.tooltip = 'Deselects all dividing edges in triangulated quads'
    cmd_deselect_triangulation = cmd
    @commands[:deselect_triangulation] = cmd
    
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
    
    cmd = UI::Command.new( 'Flip Triangulation Tool' )  { self.flip_edge_tool }
    cmd.small_icon = File.join( PATH_ICONS, 'FlipEdge_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'FlipEdge_24.png' )
    cmd.status_bar_text = 'Tool for flipping the dividing edge in triangulated quads.'
    cmd.tooltip = 'Tool for flipping the dividing edge in triangulated quads'
    cmd_flip_triangulation_tool = cmd
    @commands[:flip_triangulation_tool] = cmd
    
    cmd = UI::Command.new( 'Flip Selected Triangulation' )  { self.flip_triangulation }
    cmd.status_bar_text = 'Flips the dividing edge in the selected triangulated quads.'
    cmd.tooltip = 'Flips the dividing edge in the selected triangulated quads'
    cmd_flip_triangulation = cmd
    @commands[:flip_triangulation] = cmd
    
    cmd = UI::Command.new( 'Triangulate' )  { self.triangulate_selection }
    cmd.small_icon = File.join( PATH_ICONS, 'Triangulate_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Triangulate_24.png' )
    cmd.status_bar_text = 'Triangulate selected QuadFaces.'
    cmd.tooltip = 'Triangulate Selected QuadFaces'
    cmd_triangulate_selection = cmd
    @commands[:triangulate] = cmd
    
    cmd = UI::Command.new( 'Remove Triangulation' )  { self.remove_triangulation }
    cmd.small_icon = File.join( PATH_ICONS, 'Detriangulate_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Detriangulate_24.png' )
    cmd.status_bar_text = 'Remove triangulation from selected planar Quads.'
    cmd.tooltip = 'Remove triangulation from selected planar Quads'
    cmd_remove_triangulation = cmd
    @commands[:remove_triangulation] = cmd
    
    cmd = UI::Command.new( 'Triangulated Mesh to Quads' )  {
      self.convert_connected_mesh_to_quads
    }
    cmd.small_icon = File.join( PATH_ICONS, 'ConvertToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'ConvertToQuads_24.png' )
    cmd.status_bar_text = 'Convert triangulated mesh to Quads.'
    cmd.tooltip = 'Convert Triangulated Mesh to Quads'
    cmd_convert_connected_mesh_to_quads = cmd
    @commands[:mesh_to_quads] = cmd
    
    cmd = UI::Command.new( 'Blender Quads to SketchUp Quads' )  {
      self.convert_blender_quads_to_sketchup_quads
    }
    cmd.small_icon = File.join( PATH_ICONS, 'BlenderToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'BlenderToQuads_24.png' )
    cmd.status_bar_text = 'Convert Blender quads to SketchUp Quads.'
    cmd.tooltip = 'Convert Blender quads to SketchUp Quads'
    cmd_convert_blender_quads_to_sketchup_quads = cmd
    @commands[:blender_to_quads] = cmd
    
    cmd = UI::Command.new( 'Sandbox Quads to QuadFace Quads' )  {
      self.convert_legacy_quadmesh_to_latest
    }
    cmd.small_icon = File.join( PATH_ICONS, 'SandboxToQuads_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'SandboxToQuads_24.png' )
    cmd.status_bar_text = 'Sandbox Quads to QuadFace Quads.'
    cmd.tooltip = 'Sandbox Quads to QuadFace Quads'
    cmd_convert_legacy_quads = cmd
    @commands[:convert_legacy_quads] = cmd
    
    cmd = UI::Command.new( 'Smooth Quads' )  {
      self.smooth_quad_mesh
    }
    cmd.small_icon = File.join( PATH_ICONS, 'Smooth_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Smooth_24.png' )
    cmd.status_bar_text = 'Smooths the selected Quads\' edges.'
    cmd.tooltip = 'Smooths the selected Quads\' edges'
    cmd_smooth_quad_mesh = cmd
    @commands[:smooth_quads] = cmd
    
    cmd = UI::Command.new( 'Unsmooth Quads' )  {
      self.unsmooth_quad_mesh
    }
    cmd.small_icon = File.join( PATH_ICONS, 'Unsmooth_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'Unsmooth_24.png' )
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
    
    cmd = UI::Command.new( 'UV Map' )  {
      self.uv_map_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Map_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Map_24.png' )
    cmd.status_bar_text = 'UV Map selected Quads.'
    cmd.tooltip = 'UV Map selected Quads'
    cmd_uv_map = cmd
    @commands[:uv_map] = cmd
    
    cmd = UI::Command.new( 'UV Copy' )  {
      self.uv_copy_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Copy_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Copy_24.png' )
    cmd.status_bar_text = 'Copy UV mapping from a quad-mesh.'
    cmd.tooltip = 'Copy UV mapping from a quad-mesh'
    cmd_uv_copy = cmd
    @commands[:uv_copy] = cmd
    
    cmd = UI::Command.new( 'UV Paste' )  {
      self.uv_paste_tool
    }
    cmd.set_validation_proc  {
      ( UV_CopyTool.clipboard ) ? MF_ENABLED : MF_GRAYED
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Paste_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Paste_24.png' )
    cmd.status_bar_text = 'Paste UV mapping to a quad-mesh.'
    cmd.tooltip = 'Paste UV mapping to a quad-mesh'
    cmd_uv_paste = cmd
    @commands[:uv_paste] = cmd
    
    cmd = UI::Command.new( 'Unwrap UV Grid' )  {
      self.unwrap_uv_grid_tool
    }
    cmd.small_icon = File.join( PATH_ICONS, 'UV_Unwrap_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'UV_Unwrap_24.png' )
    cmd.status_bar_text = 'Unwraps picked UV grid.'
    cmd.tooltip = 'Unwraps picked UV grid'
    cmd_unwrap_uv_grid = cmd
    @commands[:unwrap_uv_grid] = cmd
    
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
    
    cmd = UI::Command.new( 'About QuadFace Tools�' )  {
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
    m.add_item( cmd_region_to_loop )
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
    sub_menu = m.add_submenu( 'Convert' )
    sub_menu.add_item( cmd_convert_connected_mesh_to_quads )
    sub_menu.add_separator
    sub_menu.add_item( cmd_convert_blender_quads_to_sketchup_quads )
    sub_menu.add_item( cmd_convert_legacy_quads )
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
        m.add_item( cmd_region_to_loop )
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
        sub_menu = m.add_submenu( 'Convert' )
        sub_menu.add_item( cmd_convert_connected_mesh_to_quads )
        sub_menu.add_separator
        sub_menu.add_item( cmd_convert_blender_quads_to_sketchup_quads )
        sub_menu.add_item( cmd_convert_legacy_quads )
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
    toolbar.add_item( cmd_flip_triangulation_tool )
    toolbar.add_item( cmd_triangulate_selection )
    toolbar.add_item( cmd_remove_triangulation )
    toolbar.add_separator
    toolbar.add_item( cmd_convert_connected_mesh_to_quads )
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
    height = 120
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
    
    lblAbout1 = TT::GUI::Label.new( "#{PLUGIN_NAME} (#{PLUGIN_VERSION})" )
    lblAbout1.top = 5
    lblAbout1.left = 5
    window.add_control( lblAbout1 )
    
    lblAbout2 = TT::GUI::Label.new( "#{self.extension.description}" )
    lblAbout2.top = 25
    lblAbout2.left = 5
    window.add_control( lblAbout2 )
    
    lblAbout3 = TT::GUI::Label.new( "#{self.extension.copyright}" )
    lblAbout3.bottom = 5
    lblAbout3.left = 5
    window.add_control( lblAbout3 )
    
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
    TT::Model.start_operation( 'Triangulate QuadFaces' )
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