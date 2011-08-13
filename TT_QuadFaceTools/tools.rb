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
      model = Sketchup.active_model
      # Find QuadFaces
      @faces = []
      @quads = []
      for entity in model.active_entities
        next unless QuadFace.is?( entity )
        quad = QuadFace.new( entity )
        @quads << quad
        @faces << quad.faces
      end
      @faces.flatten!
      @faces.uniq!
      # Build draw cache
      @edges = @quads.map { |quad| quad.edges }
      @edges.flatten!
      @edges.uniq!
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
    
    private
    
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
    
  end # class QuadFaceInspector
  
end # module