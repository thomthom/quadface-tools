#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # @since 0.7.0
  class WireframeToQuadsTool
  
    # @since 0.7.0
    def initialize
      @junctions = {}
      @quads = []
      @max_angle = 45.degrees
    end
    
    # @since 0.7.0
    def enableVCB?
      true
    end
    
    # @since 0.7.0
    def activate
      find_quads()
      update_ui()
      Sketchup.active_model.active_view.invalidate
    end
    
    # @since 0.7.0
    def resume( view )
      update_ui()
      view.invalidate
    end
    
    # @since 0.7.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.7.0
    def onUserText( text, view )
      begin
        max_angle = TT::Locale.string_to_float( text ).degrees
      rescue
        max_angle = @max_angle
      end
      if @max_angle != max_angle
        @max_angle = max_angle
        find_quads()
      end
      update_ui()
      view.invalidate
    end
    
    # @since 0.7.0
    def onReturn( view )
      generate_mesh()
      view.model.select_tool( nil )
    end
    
    # @since 0.7.0
    def draw( view )
      draw_quads( view )
    end
    
    private
    
    # @since 0.7.0
    def update_ui
      Sketchup.status_text = 'Press Return to generate quads from wireframe. Use the VCB to adjust allowed angle between edges between junctions.'
      Sketchup.vcb_label = 'Max Angle: '
      Sketchup.vcb_value = TT::Locale.float_to_string( @max_angle.radians )
    end
    
    # @since 0.7.0
    def find_quads
      model = Sketchup.active_model
      entities = model.active_entities # (!) Use selection
      
      max_angle = @max_angle
      
      @quads.clear
      @junctions.clear
      
      # Collect entities
      vertices = []
      edges = []
      for edge in entities
        next unless edge.is_a?( Sketchup::Edge )
        #edges << edge
        vertices << edge.vertices
      end
      vertices.flatten!
      vertices.uniq!
      
      # Find junctions
      for vertex in vertices
        next unless vertex.edges.size > 1
        if vertex.edges.size == 2
          # next if not junction
          e1, e2 = vertex.edges
          v1 = e1.line[1]
          v2 = e2.line[1]
          next if v1.angle_between( v2 ) < max_angle
        end
        @junctions[ vertex ] = vertex.position
        edges.concat( vertex.edges )
      end
      edges.flatten!
      edges.uniq!
      
      puts 'Wireframe to Quads'
      puts "> Vertices found: #{vertices.size}"
      puts "> Juntions found: #{@junctions.size}"
      
      # Find quads
      Sketchup.status_text = 'Thinking very hard...'
      processed = {}
      #stack = vertices.dup
      stack = @junctions.keys
      progress = TT::Progressbar.new( stack, 'Finding Quads' )
      until stack.empty?
        v = stack.shift
        progress.next
        for e1 in v.edges
          for vertex in e1.vertices
            v1 = other_junction_vertex( e1, vertex )
            for e2 in vertex.edges
              next if e2 == e1
              v2 = other_junction_vertex( e2, vertex )
              for e3 in v1.edges
                next if e3 == e1
                next if e3 == e2
                v3 = other_junction_vertex( e3, v1 )
                for e4 in v2.edges
                  next if e4 == e1
                  next if e4 == e2
                  next if e4 == e3
                  v4 = other_junction_vertex( e4, v2 )
                  if v3 == v4
                    verts = [ vertex, v1, v2, v3 ].sort { |x,y| y.object_id <=> x.object_id }
                    next unless verts.uniq.size == 4
                    next if processed.include?( verts )
                    
                    @quads << vertex.position
                    @quads << v1.position
                    @quads << v3.position
                    @quads << v2.position
                    
                    processed[ verts ] = verts
                  end
                end
              end
            end
          end
        end
      end
      
      puts "> Quads found: #{@quads.size / 4} (#{@quads.size}) in #{progress.elapsed_time(true)}"
      Sketchup.status_text = "Found #{@quads.size / 4} quads in #{progress.elapsed_time(true)}."
    end
    
    # @since 0.7.0
    def generate_mesh
      model = Sketchup.active_model
      progress = TT::Progressbar.new( @quads.size / 4, 'Generating mesh' )
      model.start_operation( 'Wireframe to Quads', true )
      group = model.active_entities.add_group
      provider = EntitiesProvider.new( group.entities, group.entities )
      0.step( @quads.size - 4, 4 ) { |i|
        progress.next
        quad = @quads[ i, 4 ]
        provider.add_quad( quad )
      }
      model.commit_operation
      puts "Mesh generated in #{progress.elapsed_time(true)}"
      Sketchup.status_text = "Mesh generated i #{progress.elapsed_time(true)}."
    end
    
    # @since 0.7.0
    def other_junction_vertex( edge, vertex, max_angle = 45.degrees )
      last_vertex = vertex
      last_edge = edge
      begin
        next_vertex = last_edge.other_vertex( last_vertex )
        next_edge = next_vertex.edges.find { |e| e != last_edge }
        if next_edge
          v1 = last_edge.line[1]
          v2 = next_edge.line[1]
          return next_vertex if v1.angle_between( v2 ) > max_angle
        end
        last_vertex = next_vertex
        last_edge = next_edge
      end while last_vertex.edges.size == 2
      last_vertex
    end

    # @since 0.7.0
    def draw_quads( view )
      unless @quads.empty?
        view.drawing_color = [0,0,230,64]
        view.draw( GL_QUADS, @quads )
      end
      unless @junctions.empty?
        view.line_stipple = ''
        view.line_width = 2
        view.draw_points( @junctions.values, 8, 4, [255,0,0] )
      end
    end
  
  end # class WireframeToQuadsTool
  
  
  # @since 0.3.0
  class FlipEdgeTool
    
    # @since 0.3.0
    def initialize
      @quadface = nil
      @provider = EntitiesProvider.new
    end
    
    # @since 0.3.0
    def activate
      update_ui()
    end
    
    # @since 0.3.0
    def resume( view )
      update_ui()
      view.invalidate
    end
    
    # @since 0.3.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.3.0
    def onLButtonDown( flags, x, y, view )
      if @quadface && @quadface.triangulated?
        TT::Model.start_operation( 'Flip Edge' )
        @quadface.flip_edge
        view.model.commit_operation
      end
      view.invalidate
    end
    
    # @since 0.3.0
    def onMouseMove( flags, x, y, view )
      ph = view.pick_helper
      ph.do_pick( x, y )
      face = ph.picked_face
      in_context = face && face.parent.entities == view.model.active_entities
      quad = @provider.get( face )
      if in_context && quad.is_a?( QuadFace )
        @quadface = quad
        view.invalidate
      else
        if @quadface
          @quadface = nil
          view.invalidate
        end
      end
    end
    
    # @since 0.3.0
    def draw( view )
      return unless @quadface
      view.line_stipple = ''
      view.line_width = 3
      view.drawing_color = ( @quadface.triangulated? ) ? [0,192,0] : [255,0,0]
      view.draw( GL_LINE_LOOP, @quadface.vertices.map { |v| v.position } )
      if @quadface.triangulated?
        view.line_width = 2
        view.drawing_color = [64,64,255] 
        edge = @quadface.divider
        view.draw( GL_LINES, edge.vertices.map { |v| v.position } )
      end
    end
    
    private
    
    # @since 0.3.0
    def update_ui
      Sketchup.status_text = %{Click a triangulated QuadFace to flip it's internal edge.}
    end
    
  end # class FlipEdgeTool
  
  
  # @since 0.3.0
  class ConnectTool
    
    # @since 0.3.0
    def initialize
      @selection_observer = SelectionChangeObserver.new( self )
      
      segments  = PLUGIN.settings[ :connect_splits ]
      pinch     = PLUGIN.settings[ :connect_pinch ]
      @edge_connect = PLUGIN::EdgeConnect.new( selected_edges(), segments, pinch )
      
      init_HUD()
      x = PLUGIN.settings[ :connect_window_x ]
      y = PLUGIN.settings[ :connect_window_y ]
      @window.position( x, y )
      
      # Used by onSetCursor
      @key_ctrl = false
      @key_shift = false
      
      @cursor         = TT::Cursor.get_id( :select )
      @cursor_add     = TT::Cursor.get_id( :select_add )
      @cursor_remove  = TT::Cursor.get_id( :select_remove )
    end
    
    # @since 0.3.0
    def activate
      model = Sketchup.active_model
      model.selection.remove_observer( @selection_observer )
      model.selection.add_observer( @selection_observer )
      update_ui()
      model.active_view.invalidate
    end
    
    # @since 0.3.0
    def resume( view )
      update_ui()
      view.invalidate
    end
    
    # @since 0.3.0
    def deactivate( view )
      PLUGIN.settings[ :connect_splits ] = @edge_connect.segments
      PLUGIN.settings[ :connect_pinch ] = @edge_connect.pinch
      PLUGIN.settings[ :connect_window_x ] = @window.left
      PLUGIN.settings[ :connect_window_y ] = @window.top
      view.model.selection.remove_observer( @selection_observer )
      view.invalidate
    end
    
    # @since 0.3.0
    def onLButtonDown( flags, x, y, view )
      if @window.onLButtonDown( flags, x, y, view )
        update_ui()
        view.invalidate
      end
    end
    
    # @since 0.3.0
    def onLButtonUp( flags, x, y, view )
      if @window.onLButtonUp( flags, x, y, view )
        update_ui()
        view.invalidate
      end
    end
    
    # @since 0.3.0
    def onMouseMove( flags, x, y, view )
      if @window.onMouseMove( flags, x, y, view )
        view.invalidate
        return false
      end
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      mouse_button_left = flags & MK_LBUTTON  == MK_LBUTTON
      # Modify selection my pressing the left button and hovering over edges.
      selection = view.model.selection
      if mouse_button_left
        ph = view.pick_helper
        ph.do_pick( x, y )
        return false unless edge = ph.picked_edge
        return false if QuadFace.dividing_edge?( edge )
        return false unless edge.parent.entities == view.model.active_entities
        if key_shift # Shift + Ctrl & Shift
          if selection.include?( edge )
            selection.remove( edge )
            onSelectionChange( selection ) # (!) Manual trigger. SU bugged.
            view.invalidate
          end
        elsif key_ctrl
          unless selection.include?( edge )
            selection.add( edge )
            view.invalidate
          end
        end
      end
      #view.invalidate
    end
    
    # @since 0.3.0
    def draw( view )
      @edge_connect.draw( view )
      draw_HUD( view )
    end
    
    # @since 0.3.0
    def onReturn( view )
      puts 'onReturn'
      do_splits()
      close_tool()
    end
    
    # @since 0.3.0
    def onCancel( reason, view )
      update_ui()
    end
    
    # @since 0.3.0
    def getMenu( menu )
      menu.add_item( 'Clear Selection' ) {
        Sketchup.active_model.selection.clear
      }
      menu.add_separator
      menu.add_item( 'Apply' ) { do_splits(); close_tool() }
      menu.add_item( 'Cancel' ) { close_tool() }
    end
    
    # @since 0.3.0
    def onUserText( text, view )
      if @window.active_control == @txt_splits
        # Splits
        segments = text.to_i
        if ( 1..99 ).include?( segments )
          @edge_connect.segments = segments
          update_hud()
          view.invalidate
        else
          view.tooltip = 'Splits must be between 1 and 99!'
          UI.beep
        end
      else
        # Pinch
        pinch = text.to_i
        if ( -100..100 ).include?( pinch )
          @edge_connect.pinch = pinch
          update_hud()
          view.invalidate
        else
          view.tooltip = 'Pinch must be between -100 and 100!'
          UI.beep
        end
      end
      
    rescue
      UI.beep
      raise
    ensure
      update_ui()
    end
    
    # @since 0.3.0
    def enableVCB?
      true
    end
    
    # @since 0.3.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    # @since 0.3.0
    def onKeyUp( key, repeat, flags, view )
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor()
      false
    end
    
    # @since 0.3.0
    def onSetCursor
      if @key_shift
        cursor = @cursor_remove
      elsif @key_ctrl
        cursor = @cursor_add
      else
        cursor = @cursor
      end
      UI.set_cursor( cursor )
    end
    
    # @since 0.3.0
    def onSelectionChange( selection )
      @edge_connect.cut_edges = selected_edges()
    end
    
    private
    
    # @since 0.3.0
    def update_ui
      Sketchup.status_text = 'Mouse Move + Ctrl add edges. Mouse Move + Shift removes edges. Press Return to Apply. Press ESC to Cancel.'
      if control = @window.active_control
        Sketchup.vcb_label = control.label
        Sketchup.vcb_value = control.text
      end
    end
    
    # @since 0.3.0
    def selected_edges
      Sketchup.active_model.selection.select { |e| e.is_a?( Sketchup::Edge ) }
    end
    
    # @since 0.3.0
    def close_tool
      Sketchup.active_model.active_view.model.select_tool( nil )
    end
    
    # @since 0.3.0
    def do_splits
      model = Sketchup.active_model
      TT::Model.start_operation( 'Connect Edges' )
      edges = @edge_connect.connect!
      model.selection.clear
      model.selection.add( edges )
      model.commit_operation
    end
    
    # @since 0.3.0
    def init_HUD
      view = Sketchup.active_model.active_view
      
      screen_x = ( view.vpwidth / 2 ) + 0.5
      screen_y = ( view.vpheight / 2 ) + 0.5

      @window = GL_Container.new( screen_x, screen_y, 76, 90 )
      @window.background_color = [ 0, 0, 0, 180 ]
      @window.border_color = [ 32, 32, 32 ]
      
      @titlebar = GL_Titlebar.new
      @titlebar.place( 2, 2, @window.width - 4 , 8 )
      @titlebar.background_color = [ 32, 32, 32 ]
      @titlebar.border_color = [ 32, 32, 32 ]
      @window.add_control( @titlebar )
      
      @txt_splits = GL_Textbox.new
      @txt_splits.place( 30, 15, 40, 19 )
      @txt_splits.label = 'Segments'
      @txt_splits.tooltip = 'Segments'
      @txt_splits.background_color = [ 160, 160, 160 ]
      @txt_splits.border_color = [ 32, 32, 32 ]
      @txt_splits.text = @edge_connect.segments.to_s
      @window.add_control( @txt_splits )
      
      @txt_pinch = GL_Textbox.new
      @txt_pinch.place(
        @txt_splits.left,
        @txt_splits.bottom + 5,
        @txt_splits.width,
        @txt_splits.height
      )
      @txt_pinch.label = 'Pinch'
      @txt_pinch.tooltip = 'Pinch'
      @txt_pinch.background_color = [ 160, 160, 160 ]
      @txt_pinch.border_color = [ 32, 32, 32 ]
      @txt_pinch.text = @edge_connect.pinch.to_s
      @window.add_control( @txt_pinch )
      
      @btnApply = GL_Button.new( 'Apply' ) {
        puts 'Apply!'
        do_splits()
        close_tool()
      }
      @btnApply.place( 5, @window.height - 25, 30, 20 )
      @window.add_control( @btnApply )
      
      @btnCancel = GL_Button.new( 'Cancel' ) {
        puts 'Cancel!'
        close_tool()
      }
      @btnCancel.place( @btnApply.right + 5, @window.height - 25, 30, 20 )
      @window.add_control( @btnCancel )
      
      @txt_splits.set_focus
    end
    
    # @since 0.3.0
    def update_hud
      @txt_splits.text = @edge_connect.segments.to_s
      @txt_pinch.text = @edge_connect.pinch.to_s
    end
    
    # @since 0.3.0
    def draw_HUD( view )
      update_hud()
      @window.draw( view )
      # Draw UI Graphics
      # (!) Port to GL_Image when TT_Lib 2.7 is ready.
      view.line_stipple = ''
      view.line_width = 1
      # Segments
      x = @window.rect[0].x + 7 + 0.5
      y = @txt_splits.rect(true)[0].y + 2
      rect = [x,y,0],[x+15,y,0],[x+15,y+15,0],[x,y+15,0]
      view.drawing_color = [128,128,128]
      view.draw2d( GL_LINE_LOOP, rect )
      view.drawing_color = [64,64,64]
      view.draw2d( GL_QUADS, rect )
      view.drawing_color = [100,100,255]
      view.draw2d( GL_LINES, [x+4.5,y,0],[x+4.5,y+15,0], [x+10.5,y,0],[x+10.5,y+15,0] )
      
      # Pinch
      x = @window.rect[0].x + 8 + 0.5
      y = @txt_pinch.rect(true)[0].y
      view.drawing_color = [255,255,255]
      view.draw2d( GL_LINES, [x,y+10,0],[x+5,y+10,0], [x+10,y+10,0],[x+15,y+10,0] )
      view.draw2d( GL_TRIANGLES, [x+6,y+10,0],[x+3,y+7,0],[x+3,y+13,0] )
      view.draw2d( GL_TRIANGLES, [x+9,y+10,0],[x+12,y+7,0],[x+12,y+13,0] )
      
      # Apply
      x = @btnApply.rect(true)[0].x + 8 + 0.5
      y = @btnApply.rect(true)[0].y + 10
      view.line_width = 3
      view.drawing_color = [0,168,0]
      view.draw2d( GL_LINE_STRIP, [x,y,0],[x+5,y+5,0],[x+14,y-6,0] )
      
      # Cancel
      x = @btnCancel.rect(true)[0].x + 7 + 0.5
      y = @btnCancel.rect(true)[0].y + 4
      view.line_width = 3
      view.drawing_color = [192,0,0]
      view.draw2d( GL_LINES, [x,y,0],[x+14,y+11,0],[x+14,y,0],[x,y+11,0] )
    end
    
  end # class ConnectTool
  
  
  # Selection tool specialised for quad faces. Allows selection based on quads
  # where the native tool would otherwise not perform the correct selection.
  #
  # @since 0.1.0
  class SelectQuadFaceTool
    
    COLOR_EDGE = Sketchup::Color.new( 64, 64, 64 )
    
    # @since 0.1.0
    def initialize
      @n_poles = []
      @e_poles = []
      @x_poles = []
      
      @n_cache = []
      @e_cache = []
      @x_cache = []
      
      @ui_2d = PLUGIN.settings[ :ui_2d ]
      @ui_show_poles = PLUGIN.settings[ :ui_show_poles ]
      
      @model_observer = ModelChangeObserver.new( self )
      @provider = EntitiesProvider.new
      update_geometry_cache()
      
      @doubleclick = false
      @timer_doubleclick = nil
      
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
      model = Sketchup.active_model
      view = model.active_view
      
      find_poles( view ) if @ui_show_poles
      
      model.remove_observer( @model_observer )
      model.add_observer( @model_observer )
      model.active_view.invalidate
    end
    
    # @since 0.1.0
    def resume( view )
      update_cache( view )
      view.invalidate
    end
    
    # @since 0.1.0
    def deactivate( view )
      PLUGIN.settings[ :ui_2d ] = @ui_2d
      PLUGIN.settings[ :ui_show_poles ] = @ui_show_poles
      view.model.remove_observer( @model_observer )
      view.invalidate
    end
    
    # @since 0.1.0
    def onLButtonDown( flags, x, y, view )
      picked = pick_entities( flags, x, y, view )
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      # Select the entities.
      entities = []
      if picked
        if picked.is_a?( QuadFace ) || picked.is_a?( Surface )
          entities = picked.faces
        else
          entities << picked
        end
      end
      # Check for trippleclick
      if @doubleclick
        entities = entities[0].all_connected
      end
      # Modify selection based on modifiers.
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
      # Reset trippleclick flags
      @doubleclick = false
      UI.stop_timer( @timer_doubleclick ) if @timer_doubleclick
    end
    
    # @since 0.1.0
    def onMouseMove( flags, x, y, view )
      if @ui_show_poles
        ph = view.pick_helper
        ph.init( x, y, 20 )
        for pt in @n_poles
          if ph.test_point( pt )
            view.tooltip = 'N Pole'
            return nil
          end
        end
        for pt in @e_poles
          if ph.test_point( pt )
            view.tooltip = 'E Pole'
            return nil
          end
        end
        for pt in @x_poles
          if ph.test_point( pt )
            view.tooltip = 'X Pole'
            return nil
          end
        end
      end
    end
    
    # @since 0.1.0
    def onLButtonDoubleClick( flags, x, y, view )
      picked = pick_entities( flags, x, y, view )
      if picked.is_a?( QuadFace ) || picked.is_a?( Surface )
        picked = picked.edges
      elsif picked.is_a?( Sketchup::Edge )
        faces = EntitiesProvider.new
        picked.faces.each { |face|
          faces << @provider.get( face )
        }
        picked = faces.native_entities
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
        selection.add( entities )
      end
      # For a given time after a doubleclick a trippleclick is allowed.
      @doubleclick = true
      UI.stop_timer( @timer_doubleclick ) if @timer_doubleclick
      @timer_doubleclick = UI.start_timer( 0.2, false ) { @doubleclick = false }
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyDown
    #
    # @since 0.1.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyUp
    #
    # @since 0.1.0
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
        view.line_width = 1
        view.drawing_color = COLOR_EDGE
        view.draw_lines( @lines )
      end
      draw_poles( view, @n_cache, [0,0,255] )
      draw_poles( view, @e_cache, [0,128,0] )
      draw_poles( view, @x_cache, [255,0,0] )
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onSetCursor
    #
    # @since 0.1.0
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
    
    # @since 0.2.0
    def getMenu( menu )
      m = menu.add_submenu( 'Poles' )
      i = m.add_item( 'Hightlight Poles' ) {
        toggle_poles()
      }
      m.set_validation_proc( i ) {
        ( @ui_show_poles ) ? MF_CHECKED : MF_UNCHECKED
      }
      m.add_separator
      i = m.add_item( '2D UI' ) {
        toggle_ui_2d()
      }
      m.set_validation_proc( i ) {
        ( @ui_2d ) ? MF_CHECKED : MF_UNCHECKED
      }
      menu.add_separator
      m = menu.add_submenu( 'Selection' )
      m.add_item( PLUGIN.commands[ :select_ring ] )
      m.add_item( PLUGIN.commands[ :select_loop ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :region_to_loop ] )
      m.add_item( PLUGIN.commands[ :loop_to_region ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :select_quads_from_edges ] )
      m.add_item( PLUGIN.commands[ :select_bounding_edges ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :deselect_triangulation ] )
      m = menu.add_submenu( 'Smoothing' )
      m.add_item( PLUGIN.commands[ :smooth_quads ] )
      m.add_item( PLUGIN.commands[ :unsmooth_quads ] )
      m = menu.add_submenu( 'Manipulate' )
      m.add_item( PLUGIN.commands[ :connect ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :insert_loops ] )
      m.add_item( PLUGIN.commands[ :remove_loops ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :build_corners ] )
      m.add_item( PLUGIN.commands[ :build_ends ] )
      m = menu.add_submenu( 'Triangulation' )
      m.add_item( PLUGIN.commands[ :flip_triangulation_tool ] )
      m.add_item( PLUGIN.commands[ :flip_triangulation ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :triangulate ] )
      m.add_item( PLUGIN.commands[ :remove_triangulation ] )
      m = menu.add_submenu( 'UV Mapping' )
      m.add_item( PLUGIN.commands[ :uv_map ] )
      m.add_item( PLUGIN.commands[ :uv_copy ] )
      m.add_item( PLUGIN.commands[ :uv_paste ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :unwrap_uv_grid ] )
      m = menu.add_submenu( 'Convert' )
      m.add_item( PLUGIN.commands[ :mesh_to_quads ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :wireframe_quads ] )
      m.add_separator
      m.add_item( PLUGIN.commands[ :blender_to_quads ] )
      m.add_item( PLUGIN.commands[ :convert_legacy_quads ] )
    end
    
    # @since 0.2.0
    def onModelChange( model )
      update_geometry_cache()
    end
    
    private
    
    # @since 0.1.0
    def pick_entities( flags, x, y, view )
      ph = view.pick_helper
      picked_edge = nil
      picked_quad = nil
      # Pick faces
      ph.do_pick( x, y )
      entity = ph.picked_face
      if entity && @faces.include?( entity )
        picked_quad = @provider.get( entity )
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
        picked = picked_quad#.faces
      elsif entity.is_a?( Sketchup::Face )
        surfaces = Surface.get( [entity] )
        picked = surfaces[0]#.faces # Add QuadFace or Surface objects to picked.
      end
      picked
    end
    
    # @since 0.2.0
    def update_geometry_cache
      # Collect entities.
      @faces = []
      @edges = []
      for entity in Sketchup.active_model.active_entities
        next unless QuadFace.is?( entity )
        @faces << entity
        if entity.vertices.size == 4
          for edge in entity.edges
            @edges << edge
          end
        else
          for edge in entity.edges
            @edges << edge unless QuadFace.divider_props?( edge )
          end
        end
      end
      # Build draw cache.
      @edges.uniq!
      @segments = []
      @lines = []
      for edge in @edges
        pt1 = edge.start.position
        pt2 = edge.end.position
        @segments << [ pt1, pt2 ]
        @lines << pt1
        @lines << pt2
      end
    end
    
    # @return [Nil]
    # @since 0.7.0
    def toggle_ui_2d
      @ui_2d = !@ui_2d
      view = Sketchup.active_model.active_view
      update_cache( view )
      view.invalidate
      nil
    end
    
    # @return [Nil]
    # @since 0.7.0
    def toggle_poles
      @ui_show_poles = !@ui_show_poles
      view = Sketchup.active_model.active_view
      if @ui_show_poles
        find_poles( view )
      else
        @n_poles.clear
        @e_poles.clear
        @x_poles.clear
        @n_cache.clear
        @e_cache.clear
        @x_cache.clear
      end
      view.invalidate
      nil
    end
    
    # @return [Nil]
    # @since 0.7.0
    def find_poles( view )
      @n_poles.clear
      @e_poles.clear
      @x_poles.clear
      vertices = {}
      for entity in Sketchup.active_model.active_entities
        next unless entity.is_a?( Sketchup::Edge )
        for vertex in entity.vertices
          vertices[ vertex ] = vertex
        end
      end
      vertices = vertices.keys
      for vertex in vertices
        inner = vertex.edges.select { |e| QuadFace.divider_props?( e ) }.size
        faces = vertex.faces.size - inner
        if faces == 3
          @n_poles << vertex
        elsif faces == 5
          @e_poles << vertex
        elsif faces > 5
          @x_poles << vertex
        end
      end
      update_cache( view )
      nil
    end
    
    # @return [Nil]
    # @since 0.7.0
    def update_cache( view )
      @n_cache = cache_poles( view, @n_poles )
      @e_cache = cache_poles( view, @e_poles )
      @x_cache = cache_poles( view, @x_poles )
      nil
    end
    
    # @return [Array<Geom::Point3d>]
    # @since 0.7.0
    def cache_poles( view, vertices )
      lines = []
      if @ui_2d
        for vertex in vertices
          pt = view.screen_coords( vertex.position )
          circle = TT::Geom3d.circle( pt, Z_AXIS, 10, 24 )
          circle << circle.first
          for i in ( 0...circle.size-1 )
            lines << circle[ i ]
            lines << circle[ i + 1 ]
          end
        end
      else
        normal = view.camera.direction
        for vertex in vertices
          pt = vertex.position
          size = view.pixels_to_model( 10, pt )
          circle = TT::Geom3d.circle( pt, normal, size, 24 )
          circle << circle.first
          for i in ( 0...circle.size-1 )
            lines << circle[ i ]
            lines << circle[ i + 1 ]
          end
        end
      end
      lines
    end
    
    # @return [Nil]
    # @since 0.7.0
    def draw_poles( view, poles_cache, color )
      return nil if poles_cache.empty?
      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = color
      if @ui_2d
        view.draw2d( GL_LINES, poles_cache )
      else
        view.draw( GL_LINES, poles_cache )
      end
      nil
    end
    
  end # class QuadFaceInspector
  
  
  # Observer class used by Tools to be notified on changes to the model.
  #
  # @since 0.2.0
  class ModelChangeObserver < Sketchup::ModelObserver
    
    # @since 0.2.0
    def initialize( tool )
      @tool = tool
      @delay = 0
    end
    
    # @param [Sketchup::Model] model
    #
    # @since 0.2.0
    def onTransactionStart( model )
      #puts 'onTransactionStart'
      UI.stop_timer( @delay )
    end
    
    # @param [Sketchup::Model] model
    #
    # @since 0.2.0
    def onTransactionCommit( model )
      #puts 'onTransactionCommit'
      #@tool.onModelChange( model )
      # (!) onTransactionStart and onTransactionCommit mistriggers between
      #     model.start/commit_operation.
      #
      # Because of this its impossible to know when an operation has completed.
      # Executing the cache on each change will slow everything down.
      #
      # For now a very ugly timer hack is used to delay the trigger. It's nasty,
      # filthy and only works in SU8.0+ as UI.start_timer was bugged in earlier
      # versions.
      #
      # Simple tests indicate that the delayed event triggers correctly with the
      # timer set to 0.0 - so it might work even with older versions. But more
      # testing is needed to see if it is reliable and doesn't allow for the
      # delayed event to trigger in mid-operation and slow things down.
      #
      # Since the event only trigger reading of geometry the only side-effect of
      # a mistrigger would be a slowdown.
      UI.stop_timer( @delay )
      @delay = UI.start_timer( 0.001, false ) {
        #puts 'Delayed onTransactionCommit'
        # Just to be safe in case of any modal windows being popped up due to
        # the called method the timer is killed. SU doesn't kill the timer until
        # the block has completed so a modal window will make the timer repeat.
        UI.stop_timer( @delay )
        @tool.onModelChange( model )
        model.active_view.invalidate
      }
    end
    
    # @param [Sketchup::Model] model
    #
    # @since 0.2.0
    def onTransactionUndo( model )
      #puts 'onTransactionUndo'
      @tool.onModelChange( model )
    end
    
    # @param [Sketchup::Model] model
    #
    # @since 0.2.0
    def onTransactionRedo( model )
      #puts 'onTransactionRedo'
      @tool.onModelChange( model )
    end
    
  end # class ModelChangeObserver
  
  
  # Observer class used by Tools to be notified on changes to the selection.
  #
  # @since 0.3.0
  class SelectionChangeObserver < Sketchup::SelectionObserver
    
    # @since 0.3.0
    def initialize( tool )
      @tool = tool
    end
    
    # @param [Sketchup::Selection] selection
    # @param [Sketchup::Entity] element
    #
    # @since 0.3.0
    def onSelectionAdded( selection, element )
      # (i) This event is deprecated according to the API docs. But it's the
      #     only one to trigger when a single element is added.
      #puts 'onSelectionAdded'
      selectionChanged( selection )
    end
    
    # @param [Sketchup::Selection] selection
    # @param [Sketchup::Entity] element
    #
    # @since 0.3.0
    def onSelectionRemoved( selection, element )
      # (i) This event is deprecated according to the API docs. Doesn't seem to
      #     trigger, which is a problem as onSelectionBulkChange doesn't trigger
      #     for single elements.
      #puts 'onSelectionRemoved'
      selectionChanged( selection )
    end
    
    # @param [Sketchup::Selection] selection
    #
    # @since 0.3.0
    def onSelectionBulkChange( selection )
      # (i) Does not trigger when a single element is added or removed.
      #puts 'onSelectionBulkChange'
      selectionChanged( selection )
    end
    
    # @param [Sketchup::Selection] selection
    #
    # @since 0.3.0
    def onSelectionCleared( selection )
      #puts 'onSelectionCleared'
      selectionChanged( selection )
    end
    
    private
    
    # @param [Sketchup::Selection] selection
    #
    # @since 0.3.0
    def selectionChanged( selection )
      @tool.onSelectionChange( selection )
      selection.model.active_view.invalidate
    end
    
  end # class SelectionChangeObserver
  
end # module