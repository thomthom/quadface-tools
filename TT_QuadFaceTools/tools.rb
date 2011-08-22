#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # @since 0.3.0
  class SplitFaceTool
    
    # @since 0.3.0
    def initialize
      @ip_mouse = Sketchup::InputPoint.new
      @ip_pick = Sketchup::InputPoint.new
      
      @valid_targets = []
      @source_entity = nil
      
      @polygons = []
      @segments = []
    end
    
    # @since 0.3.0
    def activate
      
    end
    
    # @since 0.3.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.3.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.3.0
    def onCancel( reason, view )
      reset()
      view.invalidate
    end
    
    # @since 0.3.0
    def onLButtonDown( flags, x, y, view )
      if @ip_mouse.edge || @ip_mouse.vertex
        if @ip_pick.valid?
          if mouse_pick_valid?
            puts 'Split!'
            pick = @ip_mouse.edge || @ip_mouse.vertex
            split_face( @ip_pick, @ip_mouse )
            
            #face = ( @source_entity.faces & pick.faces )
            #view.model.selection.clear
            #view.model.selection.add( face ) if face
            
            #reset()
            @ip_pick.copy!( @ip_mouse )
            if @ip_pick.edge
              cache_pick( @ip_pick.edge )
            elsif @ip_pick.vertex
              cache_pick( @ip_pick.vertex )
            end
          else
            view.tooltip = 'Invalid Target!'
            UI.beep
          end
        else
          @ip_pick.copy!( @ip_mouse )
        end
      else
        view.tooltip = 'Invalid Pick!'
        UI.beep
      end
      view.invalidate
    end
    
    # @since 0.3.0
    def onMouseMove( flags, x, y, view )
      @ip_mouse.pick( view, x, y )
      view.tooltip = @ip_mouse.tooltip
      
      # (i) InputPoint.depth returns 1 for Midpoint inference.
      if !@ip_pick.valid? && @ip_mouse.depth <= 1
        if @ip_mouse.edge
          Sketchup.status_text = 'Edge Pick'
          cache_pick( @ip_mouse.edge )
        elsif @ip_mouse.vertex
          Sketchup.status_text = 'Vertex Pick'
          cache_pick( @ip_mouse.vertex )
        else
          Sketchup.status_text = 'Invalid Pick'
          cache_pick( nil )
        end
      end
      
      view.invalidate
    end
    
    # @since 0.3.0
    def draw( view )
      if @ip_pick.valid?        
        pt1 = @ip_pick.position
        pt2 = @ip_mouse.position
        view.line_width = 2
        view.line_stipple = ''
        view.drawing_color = ( mouse_pick_valid? ) ? [ 0, 128, 0 ] : [ 128, 0, 0 ]
        view.draw( GL_LINES, pt1, pt2 )
        
        view.line_stipple = '-'
        spt1 = view.screen_coords( pt1 )
        spt2 = view.screen_coords( pt2 )
        view.draw2d( GL_LINES, spt1, spt2 )
      end
      
      unless @segments.empty?
        view.line_width = 3
        view.line_stipple = ''
        view.drawing_color = [ 0, 128, 0 ]
        view.draw_lines( @segments )
      end
      
      unless @polygons.empty?
        view.line_width = 3
        view.line_stipple = ''
        view.drawing_color = [ 0, 128, 0, 32 ]
        view.draw( GL_TRIANGLES, @polygons )
      end
      
      @ip_mouse.draw( view ) if @ip_mouse.display?
    end
    
    private
    
    # @since 0.3.0
    def reset
      @valid_targets.clear
      @ip_mouse.clear
      @ip_pick.clear
      @segments.clear
      @polygons.clear
    end
    
    # @since 0.3.0
    def mouse_pick_valid?
      valid = false
      if @ip_mouse.edge && @valid_targets.include?( @ip_mouse.edge )
        valid = true
      elsif @ip_mouse.vertex && @valid_targets.find { |edge|
        edge.vertices.include?( @ip_mouse.vertex )
      }
        valid = true
      end
    end
    
    # @since 0.3.0
    def split_face( ip_start, ip_end )
      start_entity = ip_start.edge || ip_start.vertex
      end_entity = ip_end.edge || ip_end.vertex
      model = start_entity.model
      entities = start_entity.parent.entities
      # Find common face
      faces = PLUGIN.connected_faces( start_entity ) # (!) Find connected surface
      face = faces.find { |face|
        if end_entity.is_a?( Sketchup::Edge )
          face.edges.include?( end_entity )
        else
          face.vertices.include?( end_entity )
        end
      }
      # Sort the two halves
      start_point = ip_start.position
      end_point = ip_end.position
      
      if face.is_a?( QuadFace )
        points = face.vertices.map { |v| v.position }
      else
        points = face.outer_loop.vertices.map { |v| v.position }
      end
      points << points.first
      
      segments = []
      for i in ( 0...points.size-1 )
        segments << points[i,2]
      end
      
      start_index = nil
      end_index = nil
      segments.each_with_index { |segment, index|
        pt1, pt2 = segment
        if TT::Point3d.between?( pt1, pt2, start_point, false )
          start_index = index
        end
        if TT::Point3d.between?( pt1, pt2, end_point, false )
          end_index = index
        end
      }
      puts "Start: #{start_index} - End: #{end_index}"
      
      if start_index < end_index
        half1 = segments[start_index+1..end_index-1]
      else
        puts 'wraparound'
        half1 = segments[start_index+1..-1] + segments[0..end_index-1]
      end
      half1 << [ half1.last[1], end_point ]
      half1 << [ end_point, start_point ]
      #half1 << [ start_point,  half1.first[0] ]
      half1.unshift( [ start_point, half1.first[0] ] )
      p half1.size
      loop1 = half1.map { |segment| segment[0] }
      #p *loop1
      #p half1
      model.start_operation( 'Split' )
      face.erase!
      f1 = entities.add_face( loop1[0..2] )
      f2 = entities.add_face( loop1[0], loop1[2], loop1[3] )
      div = ( f1.edges & f2.edges )[0]
      div.soft = true
      div.smooth = true
      model.commit_operation
      # Recreate faces / surfaces
    end
    
    # @since 0.3.0
    def cache_pick( entity )
      return false if entity == @source_entity
      @source_entity = entity
      @valid_targets.clear
      @segments.clear
      @polygons.clear
      return false if entity.nil?
      edges = []
      for face in entity.faces
        if QuadFace.is?( face )
          f = QuadFace.new( face )
        else
          f = face
        end
        edges << f.edges
        mesh = f.mesh
        for i in ( 1..mesh.count_polygons )
          @polygons.concat( mesh.polygon_points_at( i ) )
        end
      end
      edges.flatten!
      edges.uniq!
      for edge in edges
        if entity.is_a?( Sketchup::Vertex )
          @valid_targets << edge unless entity.edges.include?( edge )
        elsif entity.is_a?( Sketchup::Edge )
          @valid_targets << edge unless edge == entity
        end
        @segments << edge.start.position
        @segments << edge.end.position
      end
    end
    
  end # class SplitFaceTool
  
  
  # Selection tool specialised for quad faces. Allows selection based on quads
  # where the native tool would otherwise not perform the correct selection.
  #
  # @since 0.1.0
  class SelectQuadFaceTool
    
    COLOR_EDGE = Sketchup::Color.new( 64, 64, 64 )
    
    # @since 0.1.0
    def initialize
      @model_observer = ModelChangeObserver.new( self )
      update_geometry_cache()
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
      Sketchup.active_model.remove_observer( @model_observer )
      Sketchup.active_model.add_observer( @model_observer )
      Sketchup.active_model.active_view.invalidate
    end
    
    # @since 0.1.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.1.0
    def deactivate( view )
      view.model.remove_observer( @model_observer )
      view.invalidate
    end
    
    # @since 0.1.0
    def onLButtonDown( flags, x, y, view )
      picked = pick_entites( flags, x, y, view )
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
    
    # @since 0.1.0
    def onLButtonDoubleClick( flags, x, y, view )
      picked = pick_entites( flags, x, y, view )
      if picked.is_a?( Array )
        quad = QuadFace.new( picked[0] )
        picked = quad.edges
      elsif picked.is_a?( Sketchup::Edge )
        faces = []
        picked.faces.each { |face|
          if QuadFace.is?( face )
            quad = QuadFace.new( face )
            faces.concat( quad.faces )
          else
            faces << face
          end
        }
        picked = faces
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
        view.line_width = 1
        view.drawing_color = COLOR_EDGE
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
    
    # @since 0.2.0
    def getMenu( menu )
      menu.add_item( PLUGIN.commands[ :select ] )
      menu.add_separator
      menu.add_item( PLUGIN.commands[ :selection_grow ] )
      menu.add_item( PLUGIN.commands[ :selection_shrink ] )
      menu.add_separator
      menu.add_item( PLUGIN.commands[ :select_ring ] )
      menu.add_item( PLUGIN.commands[ :select_loop ] )
      menu.add_item( PLUGIN.commands[ :region_to_loop ] )
      menu.add_separator
      menu.add_item( PLUGIN.commands[ :smooth_quads ] )
      menu.add_item( PLUGIN.commands[ :unsmooth_quads ] )
      menu.add_separator
      menu.add_item( PLUGIN.commands[ :triangulate ] )
      menu.add_item( PLUGIN.commands[ :remove_triangulation ] )
      menu.add_separator
      menu.add_item( PLUGIN.commands[ :make_planar ] )
      menu.add_separator
      menu.add_item( PLUGIN.commands[ :split_face ] )
      menu.add_separator
      sub_menu = menu.add_submenu( 'Convert' )
      sub_menu.add_item( PLUGIN.commands[ :mesh_to_quads ] )
      sub_menu.add_item( PLUGIN.commands[ :blender_to_quads ] )
    end
    
    # @since 0.2.0
    def onModelChange( model )
      update_geometry_cache()
    end
    
    private
    
    # @since 0.1.0
    def pick_entites( flags, x, y, view )
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
            @edges << edge unless edge.soft?
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
    
  end # class ToolModelObserver
  
end # module