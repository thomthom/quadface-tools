#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # @since 0.3.0
  class GL_Rect
    
    # @since 0.3.0
    attr_accessor( :x, :y, :width, :height )
    
    # @since 0.3.0
    def initialize( x, y, width, height )
      @x = x
      @y = y
      @width = width
      @height = height
    end
    
    # @since 0.3.0
    def bottom
      @y + @height
    end
    
    # @since 0.3.0
    def right
      @x + @width
    end
    
    # @since 0.3.0
    def points
      [
        Geom::Point3d.new( @x, @y, 0 ),
        Geom::Point3d.new( @x + @width, @y, 0 ),
        Geom::Point3d.new( @x + @width, @y + @height, 0 ),
        Geom::Point3d.new( @x, @y + @height, 0 )
      ]
    end
    
    # @since 0.3.0
    def inside?( x, y )
      x >= @x && x <= right && y >= @y && y <= bottom
    end
    
  end # class GL_Rect
  
  
  # @since 0.3.0
  class GL_Window
    
    # @since 0.3.0
    attr_accessor( :rect )
    attr_accessor( :border_color, :background_color )
    
    # @since 0.3.0
    def initialize( x, y, width, height )
      @rect = GL_Rect.new( x, y, width, height )
      @border_color = Sketchup::Color.new( 32, 32, 32 )
      @background_color = Sketchup::Color.new( 128, 128, 128 )
    end
    
    # @since 0.3.0
    def draw( view )
      window_rect = @rect.points
      
      view.line_stipple = ''
      view.line_width = 1
      
      view.drawing_color = @background_color
      view.draw2d( GL_QUADS, window_rect )
      
      view.drawing_color = @border_color
      view.draw2d( GL_LINE_LOOP, window_rect )
    end
    
  end # class GL_Window
  
  
  # @since 0.3.0
  class GL_Textbox < GL_Window
    
    # @since 0.3.0
    attr_accessor( :label )
    attr_accessor( :text )
    attr_accessor( :focus )
    attr_accessor( :focus_color )
    
    # @since 0.3.0
    def initialize( x, y, width, height )
      super
      @label = ''
      @text = ''
      @text_color = Sketchup::Color.new( 0, 0, 0 )
      @focus_color = Sketchup::Color.new( 255, 255, 255 )
      @focus = false
    end
    
    # @since 0.3.0
    def draw( view )
      window_rect = @rect.points
      
      view.line_stipple = ''
      view.line_width = 1
      
      view.drawing_color = ( @focus ) ? @focus_color : @background_color
      view.draw2d( GL_QUADS, window_rect )
      
      view.drawing_color = @border_color
      view.draw2d( GL_LINE_LOOP, window_rect )
      
      x = @rect.x + 5
      y = @rect.y + 1
      pt = Geom::Point3d.new( x, y, 0 )
      view.drawing_color = @text_color
      view.draw_text( pt, @text )
    end
    
  end # class GL_Textbox
  
  
  # @since 0.3.0
  class GL_Button < GL_Window
    
    # @since 0.3.0
    attr_accessor( :label )
    attr_accessor( :color_hover, :color_pressed )
    
    # @since 0.3.0
    def initialize( x, y, width, height, &block )
      super( x, y, width, height )
      @label = ''
      @proc = block
      @background_color = Sketchup::Color.new( 0, 0, 0, 30 )
      @color_hover = Sketchup::Color.new( 0, 0, 0, 80 )
      @color_pressed = Sketchup::Color.new( 255, 160, 0, 160 )
      
      @pressed = false
      @mouseover = false
    end
    
    # @since 0.3.0
    def onLButtonDown( flags, x, y, view )
      if rect.inside?( x, y )
        @pressed = true
        view.invalidate
        true
      else
        false
      end
    end
    
    # @since 0.3.0
    def onLButtonUp( flags, x, y, view )
      if rect.inside?( x, y )
        @proc.call
        @pressed = false
        view.invalidate
        true
      else
        if @pressed
          @pressed = false
          view.invalidate
        end
        false
      end
    end
    
    # @since 0.3.0
    def onMouseMove( flags, x, y, view )
      new_state = rect.inside?( x, y )
      view.tooltip = self.label if new_state
      if new_state != @mouseover
        @mouseover = new_state
        view.invalidate
        if @mouseover
          @pressed
        else
          false
        end
      end
    end
    
    # @since 0.3.0
    def draw( view )
      window_rect = @rect.points
      
      view.line_stipple = ''
      view.line_width = 1
      
      if @pressed
        view.drawing_color = @color_pressed
      elsif @mouseover
        view.drawing_color = @color_hover
      else
        view.drawing_color = @background_color
      end
      view.draw2d( GL_QUADS, window_rect )
      
      view.drawing_color = @border_color
      view.draw2d( GL_LINE_LOOP, window_rect )
    end
    
  end # class GL_Button
  
end # module