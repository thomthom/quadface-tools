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
    attr_accessor( :left, :top, :width, :height )

    # @since 0.3.0
    def initialize( left, top, width, height )
      @left = left
      @top = top
      @width = width
      @height = height
    end

    # @since 0.3.0
    def bottom
      @top + @height
    end

    # @since 0.3.0
    def right
      @left + @width
    end

    # @since 0.3.0
    def points
      [
        Geom::Point3d.new( @left, @top, 0 ),
        Geom::Point3d.new( @left + @width, @top, 0 ),
        Geom::Point3d.new( @left + @width, @top + @height, 0 ),
        Geom::Point3d.new( @left, @top + @height, 0 )
      ]
    end

    # @since 0.3.0
    def inside?( left, top )
      left >= @left && left <= right && top >= @top && top <= bottom
    end

  end # class GL_Rect


  # @since 0.7.0
  class GL_Control

    # @since 0.7.0
    attr_accessor( :parent )
    attr_accessor( :left, :top, :width, :height )
    attr_accessor( :border_color, :background_color )
    attr_accessor( :tooltip )

    # @since 0.7.0
    def initialize
      @parent = nil

      @left = 0
      @top = 0
      @width = 50
      @height = 50

      @tooltip = nil

      @focus = false
      @can_have_focus = false

      @border_color = Sketchup::Color.new( 32, 32, 32 )
      @background_color = Sketchup::Color.new( 128, 128, 128 )
    end

    # @since 0.7.0
    def can_have_focus?
      @can_have_focus
    end

    # @since 0.7.0
    def has_focus?
      @focus == true
    end

    # @since 0.7.0
    def set_focus
      if @can_have_focus
        window.blur()
        @focus = true
        true
      else
        false
      end
    end

    # @since 0.7.0
    def draw( view )
      window_rect = rect( true )

      view.line_stipple = ''
      view.line_width = 1

      view.drawing_color = @background_color
      view.draw2d( GL_QUADS, window_rect )

      view.drawing_color = @border_color
      view.draw2d( GL_LINE_LOOP, window_rect )
    end

    # @return [Boolean]
    # @since 0.7.0
    def inside?( x, y )
      pt1, pt2, pt3, pt4 = rect( true )
      x >= pt1.x && x <= pt2.x && y >= pt1.y && y <= pt3.y
    end

    # @return [Boolean]
    # @since 0.7.0
    def place( left, top, width, height )
      @left = left
      @top = top
      @width = width
      @height = height
    end

    # @since 0.3.0
    def bottom
      @top + @height
    end

    # @since 0.3.0
    def right
      @left + @width
    end

    # @since 0.7.0
    def move( x, y )
      @left += x
      @top += y
    end

    # @since 0.7.0
    def position( x, y )
      @left = x
      @top = y
    end

    # pt4 --- pt3
    #  |       |
    #  |       |
    #  |       |
    # pt1 --- pt2
    #
    # @return [Array<Geom::Point3d>]
    # @since 0.7.0
    def rect( global = false )
      offset_x = 0.5
      offset_y = 0.5
      if global
        control = @parent
        while control
          offset_x += control.left
          offset_y += control.top
          control = control.parent
        end
      end
      [
        Geom::Point3d.new( offset_x + @left, offset_y + @top, 0 ),
        Geom::Point3d.new( offset_x + @left + @width, offset_y + @top, 0 ),
        Geom::Point3d.new( offset_x + @left + @width, offset_y + @top + @height, 0 ),
        Geom::Point3d.new( offset_x + @left, offset_y + @top + @height, 0 )
      ]
    end

    #   +---- x2,y2
    #   |       |
    #   |       |
    #   |       |
    # x1,y1 ----+
    #
    # @return [Array<Geom::Point3d>]
    # @since 0.7.0
    def coords( global = false )
      offset_x = 0.5
      offset_y = 0.5
      if global
        control = @parent
        while control
          offset_x += control.left
          offset_y += control.top
          control = control.parent
        end
      end
      [
        offset_x + @left,
        offset_y + @top,
        offset_x + @left + @width,
        offset_y + @top + @height
      ]
    end

    # @return [GL_Control]
    # @since 0.7.0
    def window
      control = self
      while control
        if control.parent.nil?
          return control
        end
        control = control.parent
      end
    end

    # @since 0.7.0
    def onLButtonDown( flags, x, y, view )
      if inside?( x, y )
        set_focus()
        true
      else
        false
      end
    end

    # @since 0.7.0
    def onLButtonUp( flags, x, y, view )
      inside?( x, y )
    end

    # @since 0.7.0
    def onMouseMove( flags, x, y, view )
      if inside?( x, y )
        view.tooltip = @tooltip if @tooltip
        true
      else
        false
      end
    end

    # @since 0.7.0
    def blur
      @focus = false
    end

  end # class GL_Control


  # @since 0.7.0
  class GL_Container < GL_Control

    # @since 0.7.0
    attr_reader( :children )

    # @since 0.7.0
    def initialize( left, top, width, height )
      super()
      place( left, top, width, height )
      @children = []
    end

    # @param [GL_Control] control
    # @since 0.7.0
    def add_control( control )
      if control.parent
        control.parent.children.remove_control( control )
      end
      @children << control
      control.parent = self
    end

    # @param [GL_Control] control
    # @since 0.7.0
    def remove_control( control )
      @children.delete( control )
    end

    # @since 0.7.0
    def draw( view )
      super( view )
      for control in @children
        control.draw( view )
      end
    end

    # @since 0.7.0
    def onLButtonDown( flags, x, y, view )
      for control in @children
        return true if control.onLButtonDown( flags, x, y, view )
      end
      super
    end

    # @since 0.7.0
    def onLButtonUp( flags, x, y, view )
      for control in @children
        return true if control.onLButtonUp( flags, x, y, view )
      end
      super
    end

    # @since 0.7.0
    def onMouseMove( flags, x, y, view )
      for control in @children
        return true if control.onMouseMove( flags, x, y, view )
      end
      super
    end

    # @since 0.7.0
    def blur
      super
      for control in @children
        control.blur()
      end
    end

    # @since 0.7.0
    def active_control
      for control in @children
        if control.is_a?( GL_Container )
          return control.active_control if control.active_control
        end
        return control if control.has_focus?
      end
      nil
    end

  end # class GL_Container


  # @since 0.3.0
  class GL_Textbox < GL_Control

    # @since 0.3.0
    attr_accessor( :label )
    attr_accessor( :text )
    attr_accessor( :focus_color )

    # @since 0.3.0
    def initialize
      super()
      @label = ''
      @text = ''
      @text_color = Sketchup::Color.new( 0, 0, 0 )
      @focus_color = Sketchup::Color.new( 255, 255, 255 )
      @can_have_focus = true
    end

    # @since 0.7.0
    def set_focus
      super
      Sketchup.vcb_label = @label
      Sketchup.vcb_value = @text
    end

    # @since 0.3.0
    def draw( view )
      window_rect = rect( true )
      x1, y1, x2, y2 = window_rect

      view.line_stipple = ''
      view.line_width = 1

      view.drawing_color = ( @focus ) ? @focus_color : @background_color
      view.draw2d( GL_QUADS, window_rect )

      view.drawing_color = @border_color
      view.draw2d( GL_LINE_LOOP, window_rect )

      x = x1.x + 5
      y = x1.y + 1
      pt = Geom::Point3d.new( x, y, 0 )
      view.drawing_color = @text_color
      view.draw_text( pt, @text )
    end

  end # class GL_Textbox


  # @since 0.3.0
  class GL_Button < GL_Control

    # @since 0.3.0
    attr_accessor( :label )
    attr_accessor( :color_hover, :color_pressed )

    # @since 0.3.0
    def initialize( label = '', &block )
      super()
      @label = label
      @proc = block
      @background_color = Sketchup::Color.new( 0, 0, 0, 30 )
      @color_hover = Sketchup::Color.new( 0, 0, 0, 80 )
      @color_pressed = Sketchup::Color.new( 255, 160, 0, 160 )

      @pressed = false
      @mouseover = false
    end

    # @since 0.3.0
    def onLButtonDown( flags, x, y, view )
      if inside?( x, y )
        @pressed = true
        view.invalidate
        true
      else
        false
      end
    end

    # @since 0.3.0
    def onLButtonUp( flags, x, y, view )
      if inside?( x, y )
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
      new_state = inside?( x, y )
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
      window_rect = rect( true )

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


  # @since 0.7.0
  class GL_Titlebar < GL_Control

    # @since 0.7.0
    def initialize
      super()
      @pressed = false
      @mouseover = false
      @last = nil
    end

    # @since 0.7.0
    def onLButtonDown( flags, x, y, view )
      if inside?( x, y )
        @last = Geom::Point3d.new( x, y, 0 )
        @pressed = true
        view.invalidate
        true
      else
        false
      end
    end

    # @since 0.7.0
    def onLButtonUp( flags, x, y, view )
      if inside?( x, y )
        #@proc.call
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

    # @since 0.7.0
    def onMouseMove( flags, x, y, view )
      mouse = Geom::Point3d.new( x, y, 0 )
      if @pressed
        offset = mouse - @last
        window.move( offset.x, offset.y )
        @last = mouse
        view.invalidate
        return true
      else
        @last = mouse
        inside?( x, y )
      end
    end

  end # class GL_Titlebar

end # module
