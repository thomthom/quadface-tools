#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
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