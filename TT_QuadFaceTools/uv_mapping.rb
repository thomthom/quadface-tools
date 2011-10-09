#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # @since 0.4.0
  class UV_UnwrapGridTool
    
    # @since 0.4.0
    def initialize
      @uv_grid = UV_GridTool.new( self, Sketchup.active_model.selection )
      @group = nil
    end
    
    # @since 0.4.0
    def activate
      if @uv_grid.mapping
        unwrap_grid( @uv_grid )
      else
        Sketchup.active_model.tools.push_tool( @uv_grid )
      end
    end
    
    # @since 0.4.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.4.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.4.0
    def onLButtonDown( flags, x, y, view )
      if @group
        view.model.commit_operation
        view.model.select_tool( nil )
      end
    end
    
    # @since 0.4.0
    def onMouseMove( flags, x, y, view )
      if @group
        ip = view.inputpoint( x, y )
        origin = @group.transformation.origin
        vector = origin.vector_to( ip.position )
        if vector.valid?
          tr = Geom::Transformation.new( vector )
          @group.transform!( tr )
        end
      end
    end
    
    def onCancel( reason, view )
      if @group
        @group = nil
        view.model.abort_operation
        @uv_grid = UV_GridTool.new( self, Sketchup.active_model.selection )
        view.model.tools.push_tool( @uv_grid )
      end
    end
    
    # @param [Array<Hash>] grid
    #
    # @return [Nil]
    # @since 0.4.0
    def unwrap_grid( grid )
      # Get U and V size
      u_size = {}
      v_size = {}
      for data in grid.mapping
        coordinate = data[ :coordinate ]
        u, v = coordinate
        v_size[v] = data[ :v_edge ].length if u == 0
        u_size[u] = data[ :u_edge ].length if v == 0
      end
      # Unwrap
      model = Sketchup.active_model
      model.start_operation( 'Unwrap UV Grid' )
      group = model.active_entities.add_group
      for data in grid.mapping
        coordinate = data[ :coordinate ]
        quad = data[ :quad ]
        u, v = coordinate
        # Calculate position
        x = 0.0
        y = 0.0
        if u < 0
          ( u...0 ).each { |i| x -= u_size[ i ] }
        else
          ( 0...u ).each { |i| x += u_size[ i ] }
        end
        if v < 0
          ( v...0 ).each { |i| y -= v_size[ i ] }
        else
          ( 0...v ).each { |i| y += v_size[ i ] }
        end
        # Calculate size
        width  = u_size[ coordinate.x ]
        height = v_size[ coordinate.y ]
        # Calculate points
        points = []
        points << Geom::Point3d.new( x, y, 0 )
        points << Geom::Point3d.new( x + width, y, 0 )
        points << Geom::Point3d.new( x + width, y + height, 0 )
        points << Geom::Point3d.new( x, y + height, 0 )
        # Recreate unwrapped quad
        #   Edges must be created in a spesific order so we can transfer the UV
        #   mapping correctly.
        u1_edge = group.entities.add_line( points[0], points[1] )
        v1_edge = group.entities.add_line( points[0], points[3] )
        u2_edge = group.entities.add_line( points[2], points[3] )
        v2_edge = group.entities.add_line( points[1], points[2] )
        face = group.entities.add_face( u1_edge, v2_edge, u2_edge, v1_edge )
        face.reverse! if face.normal.z < 0
        # Order vertex data
        new_data = {}
        new_data[ :u_edge ] = u1_edge
        new_data[ :v_edge ] = v1_edge
        new_data[ :u2_edge ] = u2_edge
        new_data[ :v2_edge ] = v2_edge
        source_vertices = grid.ordered_vertices( data )
        vertices = grid.ordered_vertices( new_data )
        # Match triangulation
        if quad.triangulated?
          edge = quad.divider
          indexes = edge.vertices.map { |v| source_vertices.index( v ) }
          new_points = indexes.map { |i| vertices[ i ] }
          new_edge = group.entities.add_line( new_points[0], new_points[1] )
          QuadFace.set_divider_props( new_edge )
        end
        # Get the new quad
        new_quad = QuadFace.new( face )
        # Transfer UV mapping
        front_material = quad.material
        back_material = quad.back_material
        if front_material && front_material.texture
          uv_data = quad.uv_get
          new_uv_data = {}
          source_vertices.each_with_index { |vertex, index|
            uv = uv_data[ vertex ]
            v = vertices[ index ]
            new_uv_data[ v ] = uv
          }
          new_quad.uv_set( front_material, new_uv_data )
        else
          new_quad.material = front_material
        end
        if back_material && back_material.texture
          uv_data = quad.uv_get( false )
          new_uv_data = {}
          source_vertices.each_with_index { |vertex, index|
            uv = uv_data[ vertex ]
            v = vertices[ index ]
            new_uv_data[ v ] = uv
          }
          new_quad.uv_set( back_material, new_uv_data, false )
        else
          new_quad.back_material = back_material
        end
      end
      Sketchup.active_model.selection.add( group )
      @group = group
      nil
    end
  
  end # class UV_UnwrapGridTool
  
  
  # @since 0.4.0
  class UV_CopyTool
    
    @@clipboard = nil
    
    # @since 0.4.0
    def self.clipboard
      @@clipboard
    end
    
    # @since 0.4.0
    def initialize
      @uv_grid = UV_GridTool.new( self, Sketchup.active_model.selection )
    end
    
    # @since 0.4.0
    def activate
      if @uv_grid.mapping
        copy_uv( @uv_grid )
        Sketchup.active_model.select_tool( nil )
      else
        Sketchup.active_model.tools.push_tool( @uv_grid )
      end
    end
    
    # @since 0.4.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.4.0
    def deactivate( view )
      view.invalidate
    end
    
    # @param [Array<Hash>] grid
    #
    # @return [Nil]
    # @since 0.4.0
    def copy_uv( grid, front = true )
      uv_mapping = {}
      for data in grid.mapping
        coordinate = data[ :coordinate ]
        quad = data[ :quad ]
        vertices = grid.ordered_vertices( data )
        source_uv = quad.uv_get( front )
        new_uv = Array.new( 4 )
        for vertex, uv in source_uv
          index = vertices.index( vertex )
          new_uv[ index ] = uv
        end
        uv_mapping[ coordinate ] = {
          :material => quad.material,
          :uv_mapping => new_uv
        }
      end
      @@clipboard = uv_mapping
      nil
    end
  
  end # class UV_TransferTool
  
  
  # @since 0.4.0
  class UV_PasteTool
    
    # @since 0.4.0
    def initialize
      @uv_grid = UV_GridTool.new( self, Sketchup.active_model.selection )
    end
    
    # @since 0.4.0
    def activate
      if @uv_grid.mapping
        paste_uv( @uv_grid )
        Sketchup.active_model.select_tool( nil )
      else
        Sketchup.active_model.tools.push_tool( @uv_grid )
      end
    end
    
    # @since 0.4.0
    def resume( view )
      view.invalidate
    end
    
    # @since 0.4.0
    def deactivate( view )
      view.invalidate
    end
    
    # @param [Array<Hash>] grid
    #
    # @return [Nil]
    # @since 0.4.0
    def paste_uv( grid, front = true )
      TT::Model.start_operation( 'Paste UV Mapping' )
      uv_mapping = UV_CopyTool.clipboard
      for data in grid.mapping
        coordinate = data[ :coordinate ]
        quad = data[ :quad ]
        # Fetch data from clipboard source
        source_data = uv_mapping[ coordinate ]
        next unless source_data
        material = source_data[ :material ]
        # Validate Material
        next unless TT::Material.in_model?( material )
        # Apply Material
        if material && material.texture
          vertices = grid.ordered_vertices( data )
          uv_data = source_data[ :uv_mapping ]
          new_uv = {}
          for i in ( 0..3 )
            vertex = vertices[i]
            uv = uv_data[i]
            new_uv[ vertex ] = uv
          end
          quad.uv_set( material, new_uv, front )
        else
          if front
            quad.material = material
          else
            quad.back_material = material
          end
        end
      end
      Sketchup.active_model.commit_operation
      nil
    end
  
  end # class UV_TransferTool
  
  
  # @since 0.4.0
  class UV_MapTool
    
    CLR_U_AXIS = Sketchup::Color.new( 192, 0, 0 )
    CLR_V_AXIS = Sketchup::Color.new( 0, 128, 0 )
    
    # @since 0.4.0
    def initialize
      @ip_mouse = Sketchup::InputPoint.new
      
      @u_axis = nil # Array<Vertex>
      @v_axis = nil
      @u_origin = nil # Integer
      @v_origin = nil
      
      @u_scale = nil # Float OR Length
      @v_scale = nil
      
      @u_handle = nil # Point3D
      @v_handle = nil
      @u_handle_active = false
      @v_handle_active = false
      @u_handle_mouse = false
      @v_handle_mouse = false
      
      @uv_grid = UV_GridTool.new( self, Sketchup.active_model.selection )
    end
    
    # @since 0.4.0
    def enableVCB?
      return true
    end
    
    # @since 0.4.0
    def activate
      #puts 'UVMapTool'
      @draw_uv_grid = PLUGIN.settings[ :uv_draw_uv_grid ]
      @continuous = PLUGIN.settings[ :uv_continuous ]
      @scale_proportional = PLUGIN.settings[ :uv_scale_proportional ]
      @u_scale = PLUGIN.settings[ :uv_u_scale ]
      @v_scale = PLUGIN.settings[ :uv_v_scale ]
      
      #p @u_scale 
      #p @v_scale
        
      if @uv_grid.mapping
        #puts '> Mapping...'
        
        calculate_axes()
        @u_handle = point_on_axis( @u_origin, @u_axis, @u_scale )
        @v_handle = point_on_axis( @v_origin, @v_axis, @v_scale )
        
        TT::Model.start_operation( 'UV Map Quads' )
        map_mesh()
        Sketchup.active_model.commit_operation
        
        update_ui()
      else
        #puts '> No Grid'
        Sketchup.active_model.tools.push_tool( @uv_grid )
      end
    end
    
    # @since 0.4.0
    def resume( view )
      update_ui()
      view.invalidate
    end
    
    # @since 0.4.0
    def deactivate( view )
      PLUGIN.settings[ :uv_draw_uv_grid ] = @draw_uv_grid
      PLUGIN.settings[ :uv_continuous ] = @continuous
      PLUGIN.settings[ :uv_scale_proportional ] = @scale_proportional
      PLUGIN.settings[ :uv_scale_absolute ] = @u_scale.is_a?( Length )
      if @u_scale && @v_scale # (!) HOTFIX - uncaught error sets the scale to nil.
        PLUGIN.settings[ :uv_u_scale ] = @u_scale
        PLUGIN.settings[ :uv_v_scale ] = @v_scale
      else
        puts 'QuadFace Tool - Warning! Tried to save scale with nil values.'
      end
      
      view.invalidate
    end
    
    # @since 0.4.0
    def onLButtonDown( flags, x, y, view )
      if ip = pick_on_axis( @u_axis, x, y, view )
        #puts 'Start U'
        view.model.start_operation( 'Change U Scale' )
        scale_u( ip )
      elsif ip = pick_on_axis( @v_axis, x, y, view )
        #puts 'Start V'
        view.model.start_operation( 'Change V Scale' )
        scale_v( ip )
      end
      view.invalidate
    end
    
    # @since 0.4.0
    def onLButtonUp( flags, x, y, view )
      if @u_handle_active || @v_handle_active
        #puts 'Commit'
        view.model.commit_operation
      end
    end
    
    # @since 0.4.0
    def onMouseMove( flags, x, y, view )
      if ip_u = pick_on_axis( @u_axis, x, y, view )
        @ip_mouse.copy!( ip_u )
      elsif ip_v = pick_on_axis( @v_axis, x, y, view )
        @ip_mouse.copy!( ip_v )
      else
        @ip_mouse.clear
      end
      
      if flags & MK_LBUTTON == MK_LBUTTON
        # Modify the U or V scale.
        if ip_u
          scale_u( ip_u )
        elsif ip_v
          scale_v( ip_v )
        end
      else
        # Detect if the U or V handle is interacted with.
        # (i) Currently does nothing. Might not be needed?
        ph = view.pick_helper
        if @u_handle && ph.test_point( @u_handle, x, y, 10 )
          @u_handle_mouse = true
        elsif @v_handle && ph.test_point( @v_handle, x, y, 10 )
          @v_handle_mouse = true
        else
          @u_handle_mouse = false
          @v_handle_mouse = false
        end
      end
      view.invalidate
    end
    
    # @since 0.4.0
    def onCancel( reason, view )
      if reason == 0 # ESC
        if @u_handle_active || @v_handle_active
          #puts 'Abort'
          view.model.abort_operation
        end
      end
    end
    
    # @since 0.4.0
    def onUserText( text, view )
      if TT::Locale.decimal_separator == '.'
        reg = /^\s*([a-zA-Z0-9.]+)\s*,\s*([a-zA-Z0-9.]+)\s*$/
      else
        reg = /^\s*([a-zA-Z0-9,]+)\s*;\s*([a-zA-Z0-9,]+)\s*$/
      end
      result = text.match( reg )
      unless result
        UI.beep
        update_ui()
        return nil
      end
      u = result[1]
      v = result[2]
      begin
        if u.match( /^[0-9]+([,.][0-9]+)?$/ )
          u = TT::Locale.string_to_float(u)
          v = TT::Locale.string_to_float(v)
        else
          u = u.to_l
          v = v.to_l
        end
      rescue
        UI.beep
        raise
      ensure
        update_ui()
      end
      @u_scale = u
      @v_scale = v
      @u_handle = point_on_axis( @u_origin, @u_axis, @u_scale )
      @v_handle = point_on_axis( @v_origin, @v_axis, @v_scale )
      TT::Model.start_operation( 'Change UV Scale' )
      map_mesh()
      view.model.commit_operation
      update_ui()
    end
    
    # @since 0.4.0
    def draw( view )
      @uv_grid.draw( view ) if @draw_uv_grid
      
      view.line_stipple = ''
      
      unless @u_axis.empty?
        # Illustrate axis.
        view.line_width = 3
        view.drawing_color = CLR_U_AXIS
        pts = @u_axis.map { |v| v.position }
        view.draw( GL_LINE_STRIP, pts )
        
        # Indicate start of axis.
        view.draw_points( pts[0,1], 8, 4, CLR_U_AXIS )
        
        # Axis handle grip
        pt = @u_handle
        if pt
          view.line_width = 2
          square = ( @u_handle_mouse ) ? 2 : 4 # Filled | Cross
          view.draw_points( [pt], 10, 1, CLR_U_AXIS )
          view.line_width = 1
          view.draw_points( [pt], 10, square, CLR_U_AXIS )
        end
      end
      
      unless @v_axis.empty?
        # Illustrate axis.
        view.line_width = 3
        view.drawing_color = CLR_V_AXIS
        pts = @v_axis.map { |v| v.position }
        view.draw( GL_LINE_STRIP, pts )
        
        # Indicate start of axis.
        view.draw_points( pts[0,1], 8, 4, CLR_V_AXIS )
        
        # Axis handle grip
        pt = @v_handle
        if pt
          view.line_width = 2
          square = ( @v_handle_mouse ) ? 2 : 4 # Filled | Cross
          view.draw_points( [pt], 10, 1, CLR_V_AXIS )
          view.line_width = 1
          view.draw_points( [pt], 10, square, CLR_V_AXIS )
        end
      end
      
      # InputPoint indicating interaction with the axis.
      @ip_mouse.draw( view ) if @ip_mouse.display?
    end
    
    # @since 0.4.0
    def getMenu( context_menu )
      m = context_menu.add_item( 'Continuous Mapping' ) {
        @continuous = !@continuous
        # Check if mesh can be mapped continously
        if @continuous && !@uv_grid.get_mapping_grid( @uv_grid.mapping )
          UI.messagebox( 'This mesh cannot be mapped to a 2D grid and continuous is therefore not possible.' )
        end
        TT::Model.start_operation( 'Toggle Continuous Mapping' )
        map_mesh()
        Sketchup.active_model.commit_operation
      }
      context_menu.set_validation_proc( m ) {
        ( @continuous ) ? MF_CHECKED : MF_UNCHECKED
      }
      
      #m = context_menu.add_item( 'Skew and Distort' ) { puts '02' }
      #context_menu.set_validation_proc( m ) { MF_CHECKED | MF_GRAYED }
      
      m = context_menu.add_item( 'Scale Proportionally' ) {
        @scale_proportional = !@scale_proportional 
      }
      context_menu.set_validation_proc( m ) {
        ( @scale_proportional ) ? MF_CHECKED : MF_UNCHECKED
      }
      
      context_menu.add_separator
      
      context_menu.add_item( 'Use Material Size' ) {
        material = Sketchup.active_model.materials.current
        if material && material.texture
          @u_scale = material.texture.width.to_l
          @v_scale = material.texture.height.to_l
          @u_handle = point_on_axis( @u_origin, @u_axis, @u_scale )
          @v_handle = point_on_axis( @v_origin, @v_axis, @v_scale )
          TT::Model.start_operation( 'Use Material Size' )
          map_mesh()
          Sketchup.active_model.commit_operation
          update_ui()
          Sketchup.active_model.active_view.invalidate
        end
      }
      
      context_menu.add_item( 'Flip U and V Scale' ) {
        @u_scale, @v_scale = [ @v_scale, @u_scale ]
        @u_handle = point_on_axis( @u_origin, @u_axis, @u_scale )
        @v_handle = point_on_axis( @v_origin, @v_axis, @v_scale )
        TT::Model.start_operation( 'Flip U and V Scale' )
        map_mesh()
        Sketchup.active_model.commit_operation
        update_ui()
        Sketchup.active_model.active_view.invalidate
      }
      
      context_menu.add_separator
      
      m = context_menu.add_item( 'Show UV Grid' ) {
        @draw_uv_grid = !@draw_uv_grid 
        Sketchup.active_model.active_view.invalidate
      }
      context_menu.set_validation_proc( m ) {
        ( @draw_uv_grid ) ? MF_CHECKED : MF_UNCHECKED
      }
    end
    
    # @return [Nil]
    # @since 0.4.0
    def update_ui
      Sketchup.status_text = 'Set U and V mapping scale.'
      decimal = TT::Locale.decimal_separator
      list_separator = ( decimal == '.' ) ? ',' : ';'
      Sketchup.vcb_label = 'UV Scale'
      if @u_scale.is_a?( Length )
        u = @u_scale.to_s
        v = @v_scale.to_s
      else
        u = format_float( @u_scale, 2 )
        v = format_float( @v_scale, 2 )
      end
      Sketchup.vcb_value = "#{u}#{list_separator} #{v}"
      nil
    end
    
    # @note Taken from TT_Lib2 temporarily as 2.5 is bugged.
    #
    # @param [Numeric] float
    # @param [Integer] precision
    #
    # @return [String]
    # @since 0.4.0
    def format_float( float, precision )
      num = sprintf( "%.#{precision}f", float )
      if num.to_f != float
        num = "~ #{num}"
      end
      num.tr!( '.', TT::Locale.decimal_separator )
      num
    end
    
    # @param [Array<Sketchup::Vertex>] axis
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [Sketchup::InputPoint,Nil]
    # @since 0.4.0
    def pick_on_axis( axis, x, y, view )
      ip = view.inputpoint( x, y )
      if vertex = ip.vertex
        return ip if axis.include?( vertex )
      elsif edge = ip.edge
        edges = []
        for i in (0...axis.size-1)
          v1 = axis[i]
          v2 = axis[i+1]
          edges << v1.common_edge( v2 )
        end
        return ip if edges.include?( edge )
      else
        return nil
      end
    end
    
    # @param [Geom::Point3d] point
    # @param [Array<Sketchup::Vertex>] axis
    # @param [Integer] origin Index of origin vertex in axis
    #
    # @return [Length,Nil]
    # @since 0.4.0
    def point_on_axis_to_length( point, axis, origin = 0 )
      length = 0.to_l
      for i in (origin...axis.size-1)
        v1 = axis[i]
        v2 = axis[i+1]
        edge = v1.common_edge( v2 )
        if TT::Edge.point_on_edge?( point, edge )
          return ( length + v1.position.distance( point ) ).to_l
        end
        length += edge.length
      end
      return nil
    end
    
    # @param [Geom::Point3d] point
    # @param [Array<Sketchup::Vertex>] axis
    # @param [Integer] origin Index of origin vertex in axis
    #
    # @return [Float,Nil]
    # @since 0.4.0
    def point_on_axis_to_ratio( point, axis, origin = 0 )
      ratio = 0.0
      for i in (origin...axis.size-1)
        v1 = axis[i]
        v2 = axis[i+1]
        edge = v1.common_edge( v2 )
        if TT::Edge.point_on_edge?( point, edge )
          local_length = v1.position.distance( point )
          local_ratio = local_length / edge.length
          return 1.0 / ( ratio + local_ratio )
        end
        ratio += 1.0
      end
      return nil
    end
    
    # @param [Sketchup::InputPoint] ip
    #
    # @return [Nil]
    # @since 0.4.0
    def scale_u( ip )
      if @u_scale.is_a?( Length )
        scale = point_on_axis_to_length( ip.position, @u_axis, @u_origin )
      else
        scale = point_on_axis_to_ratio( ip.position, @u_axis, @u_origin )
      end
      unless scale
        UI.beep
        return
      end
      @u_handle = ip.position
      @u_handle_active = true
      @v_handle_active = false
      ratio = @v_scale / @u_scale
      @u_scale = scale
      if @scale_proportional
        @v_scale = ( @u_scale * ratio ).to_l
      end
      map_mesh()
      update_ui()
    end
    
    # @param [Sketchup::InputPoint] ip
    #
    # @return [Nil]
    # @since 0.4.0
    def scale_v( ip )
      if @v_scale.is_a?( Length )
        scale = point_on_axis_to_length( ip.position, @v_axis, @v_origin )
      else
        scale = point_on_axis_to_ratio( ip.position, @v_axis, @v_origin )
      end
      unless scale
        UI.beep
        return
      end
      @v_handle = ip.position
      @u_handle_active = false
      @v_handle_active = true
      ratio = @u_scale / @v_scale
      @v_scale = scale
      if @scale_proportional
        @u_scale = ( @v_scale * ratio ).to_l
      end
      map_mesh()
      update_ui()
    end
    
    # @return [Nil]
    # @since 0.4.0
    def calculate_axes
      origin = @uv_grid.origin
      u_edge = @uv_grid.u_edge
      v_edge = @uv_grid.v_edge
      
      axes = get_axes( @uv_grid.mapping )
      #Sketchup.active_model.selection.add( axes.x )
      #Sketchup.active_model.selection.add( axes.y )
      @u_axis = get_axis( axes.x, origin, u_edge )
      @v_axis = get_axis( axes.y, origin, v_edge )
      
      @u_origin = @u_axis.index( origin )
      @v_origin = @v_axis.index( origin )
      nil
    end
    
    # @return [Nil]
    # @since 0.4.0
    def map_mesh
      if @continuous && @uv_grid.get_mapping_grid( @uv_grid.mapping )
        # Continuous Mapping
        if @u_scale.is_a?( Length )
          u_mapping = map_axis_to_uv( @u_origin, @u_axis, @u_scale )
          v_mapping = map_axis_to_uv( @v_origin, @v_axis, @v_scale )
          @uv_grid.map_grid_by_length( @uv_grid.mapping, u_mapping, v_mapping )
        else
          @uv_grid.map_grid_by_ratio( @uv_grid.mapping, @u_scale, @v_scale )
        end
      else
        # Induvidual Mapping
        @uv_grid.map_mesh_induvidually( @uv_grid.mapping, @u_scale, @v_scale )
      end
      nil
    end
    
    # @param [Integer] origin_index Index of the vertex representing the origin
    # @param [Array<Sketchup::Vertex>] axis
    # @param [Length,Float] length
    #
    # @return [Hash]
    # @since 0.4.0
    def point_on_axis( origin_index, axis, length )
      if @u_scale.is_a?( Length )
        total_length = 0.to_l
        origin_index.upto( axis.size-2 ) { |i|
          v1 = axis[ i ]
          v2 = axis[ i + 1 ]
          edge = v1.common_edge( v2 )
          break unless edge
          if length >= total_length && length <= total_length + edge.length
            diff = length - total_length
            direction = v1.position.vector_to( v2.position )
            return v1.position.offset( direction, diff )
          end
          total_length += edge.length
        }
      else
        i = ( 1.0 / length ).to_i
        index = origin_index + i
        return nil unless index <= axis.size
        v1 = axis[ index ]
        v2 = axis[ index + 1 ]
        return nil unless v1 && v2
        edge = v1.common_edge( v2 )
        ratio = ( 1.0 / length ) % 1.0
        distance = edge.length * ratio
        direction = v1.position.vector_to( v2.position )
        return v1.position.offset( direction, distance )
      end
      nil
    end
    
    # @param [Integer] origin_index Index of the vertex representing the origin
    # @param [Array<Sketchup::Vertex>] axis
    # @param [Float] scale
    #
    # @return [Hash]
    # @since 0.4.0
    def map_axis_to_uv( origin_index, axis, scale )
      #puts "map_axis_to_uv - #{axis.size}"
      mapping = {}
      if scale.is_a?( Length )
        # Positive direction
        length = 0.to_l
        origin_index.upto( axis.size-1 ) { |i|
          # Grid cocordinate
          c = i - origin_index
          # Get UV co-ordinate
          uv = length / scale
          mapping[ c ] = uv
          # Get the next length
          v1 = axis[ i ]
          v2 = axis[ i + 1 ]
          break unless v1 && v2
          edge = v1.common_edge( v2 )
          #puts "> (P) i: #{i} - c: #{c} - v1: #{v1} - v2: #{v2} - e: #{edge}"
          next unless edge
          length += edge.length
        }
        # Negative direction
        length = 0.to_l
        origin_index.downto( 0 ) { |i|
          # Grid cocordinate
          c = i - origin_index
          # Get UV co-ordinate (Note negative length!)
          uv = -length / scale
          mapping[ c ] = uv
          # Get the next length
          v1 = axis[ i ]
          v2 = axis[ i - 1 ]
          break unless v1 && v2
          edge = v1.common_edge( v2 )
          #puts "> (N) i: #{i} - c: #{c} - v1: #{v1} - v2: #{v2} - e: #{edge}"
          next unless edge
          length += edge.length
        }
      else
        raise( ArgumentError, 'Scale must be Length.' )
      end
      mapping
    end
    
    # @param [Array<Sketchup::Edge>] axis Unsorted array of edges.
    # @param [Sketchup::Vertex] origin A vertex from one of the edges in +axis+.
    # @param [Sketchup::Edge] edge Connected to +origin+.
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 0.4.0
    def get_axis( axis, origin, edge )
      sorted_loop = TT::Edges.sort( axis )
      vertices = TT::Edges.sort_vertices( sorted_loop )
      index = vertices.index( origin )
      next_index = vertices.index( edge.other_vertex( origin ) )
      # Check direction
      if index + 1 != next_index
        vertices.reverse!
        index = vertices.index( origin )
      end
      # Check loops, ensure they start at origin.
      if vertices.first == vertices.last
        unless vertices.first == origin
          # i=4
          # x=[0,1,2,3,4,5,6,7,8,9,0]
          # y=x[i...-1] + x[0..i]
          # > [4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4]
          vertices = vertices[index...-1] + vertices[0..index]
        end
      end
      vertices
    end
    
    # @param [Array<Hash>] mapping_set
    #
    # @return [Array<Array<Sketchup::Edge>,Array<Sketchup::Edge>]
    # @since 0.4.0
    def get_axes( mapping_set )
      # Check for loops
      looping_u = true
      looping_v = true
      # (!) In Looping rows the coordinates might not align themselves if there
      #     is a hole in the mesh on the positive side of the axis. The mapping
      #     shifts due to the way it traverses the mesh.
      #max_u = 0
      #max_v = 0
      for data in mapping_set
        u = data[ :coordinate ].x
        v = data[ :coordinate ].y
        looping_u = false if u < 0
        looping_v = false if v < 0
        #max_u = u if u > max_u
        #max_v = v if v > max_v
      end
      u_axis = []
      v_axis = []
      for data in mapping_set
        u = data[ :coordinate ].x
        v = data[ :coordinate ].y
        if u == 0
          v_axis << data[ :v_edge ]
        end
        if v == 0
          u_axis << data[ :u_edge ]
        end
        if looping_u
          #v_axis << data[ :v2_edge ] if u == max_u
        else
          v_axis << data[ :v2_edge ] if u == -1
        end
        if looping_v
          #u_axis << data[ :u2_edge ] if v == max_v
        else
          u_axis << data[ :u2_edge ] if v == -1
        end
      end
      [ u_axis.uniq, v_axis.uniq ]
    end
    
  end # class UV_MapTool
  
  
  # Tool class used to pick the origin, u and v direction for the UV mapping
  # of a mesh. Once that is picked a second tool is pushed to the tool stack
  # and takes over the processing.
  #
  # The tool requires the user to pick a point of origin and U and V direction.
  # From that, the quad-mesh is traversed and mapped into a 2D grid if possible.
  #
  # When a 2D grid has been mapped, it can be traversed and addressed using
  # simple X,Y coordinates. This predictabilty makes it easy to map the mesh.
  #
  # @since 0.4.0
  class UV_GridTool
    
    CLR_MOUSE   = Sketchup::Color.new( 255, 64, 0 )
    CLR_PICKED  = Sketchup::Color.new( 64, 64, 255 )
    CLR_VALID   = Sketchup::Color.new( 0, 192, 0 )
    
    CLR_MATRIX = [
      Sketchup::Color.new( 255, 64, 0, 40 ),
      Sketchup::Color.new( 0, 164, 0, 40 ),
      Sketchup::Color.new( 0, 0, 192, 40 )
    ]
    
    attr_reader( :mapping, :contraints )
    attr_reader( :origin, :u_edge, :v_edge )
    
    # @param [Sketchup::Tool] parent_tool
    # @param [Enumerable] contraints Set of faces to contrain mapping to.
    #
    # @since 0.4.0
    def initialize( parent_tool, contraints = [] )
      @child_tool = parent_tool
      
      @origin = nil
      @u_edge = nil
      @v_edge = nil
      
      @ip_mouse = Sketchup::InputPoint.new
      @mouse_origin = nil
      @mouse_u = nil
      @mouse_v = nil
      
      @valid_pick = nil
      
      @preview_quads = [ [], [], [] ]
      @mapping = nil
      
      @contraints = {}
      for e in contraints
        next unless e.is_a?( Sketchup::Face )
        @contraints[ e ] = e
      end
    end
    
    # @since 0.4.0
    def activate
      #puts 'UV_Grid'
      update_ui()
    end
    
    # @since 0.4.0
    def resume( view )
      update_ui()
      view.invalidate
    end
    
    # @since 0.4.0
    def deactivate( view )
      view.invalidate
    end
    
    # @since 0.4.0
    def onCancel( reason, view )
      # 0: the user canceled the current operation by hitting the escape key.
      # 1: the user re-selected the same tool from the toolbar or menu.
      # 2: the user did an undo while the tool was active.
      if reason == 0
        if state_pick_u?
          @origin = nil
          @valid_pick = nil
          view.invalidate
        elsif state_pick_v?
          @u_edge = nil
          @valid_pick = @origin.edges.select { |e|
            !QuadFace.dividing_edge?( e )
          }
          view.invalidate
        end
      elsif reason == 1
        @origin = nil
        @u_edge = nil
        @v_edge = nil
        view.invalidate
      end
    end
    
    # @since 0.4.0
    def onLButtonDown( flags, x, y, view )
      if state_pick_origin?
        @origin = @mouse_origin if @mouse_origin
        @u_edge = @mouse_edge if @mouse_edge
        # Valid next pick
        if @u_edge
          quads = PLUGIN.connected_quad_faces( @u_edge )
          @valid_pick = quads.map { |quad|
            e = ( ( @origin.edges & quad.edges ) - [ @u_edge ] )[0]
          }.flatten
        elsif @origin
          @valid_pick = @origin.edges.select { |e|
            !QuadFace.dividing_edge?( e )
          }
        end
      elsif state_pick_u? && @valid_pick.include?( @mouse_edge )
        @u_edge = @mouse_edge if @mouse_edge
        # Valid next pick
        quads = PLUGIN.connected_quad_faces( @u_edge )
        @valid_pick = quads.map { |quad|
          e = ( ( @origin.edges & quad.edges ) - [ @u_edge ] )[0]
        }.flatten
      elsif state_pick_v? && @valid_pick.include?( @mouse_edge )
        @v_edge = @mouse_edge if @mouse_edge
        @valid_pick = nil
        @mapping = compute_mapping()
        #puts '> Pushing child tool...'
        view.model.tools.push_tool( @child_tool )
        @mouse_origin = nil
        @mouse_edge = nil
        @ip_mouse.clear
      else
        UI.beep
      end
      update_ui()
      view.invalidate
    end
    
    # @since 0.4.0
    def onMouseMove( flags, x, y, view )
      @ip_mouse.pick( view, x, y )
      
      @mouse_edge = nil
      @mouse_origin = nil
      
      if state_pick_origin?
        if edge = @ip_mouse.edge
          if QuadFace.entity_in_quad?( edge )
            pts = edge.vertices.map { |v| v.position }
            unless QuadFace.dividing_edge?( edge )
              @mouse_edge = edge
            end
            # Find Origin
            pt = @ip_mouse.position
            d1 = pts[0].distance( pt )
            d2 = pts[1].distance( pt )
            origin = ( d1 < d2 ) ? edge.start : edge.end
            @mouse_origin = origin
          end
        elsif vertex = @ip_mouse.vertex
          if QuadFace.entity_in_quad?( vertex )
            @mouse_origin = vertex
          end
        elsif face = @ip_mouse.face
          if QuadFace.is?( face )
            quad = QuadFace.new( face )
            # Find Origin
            pt = @ip_mouse.position
            distance = nil
            origin = nil
            for vertex in quad.vertices
              d = pt.distance( vertex.position )
              if distance.nil? || d < distance
                distance = d
                origin = vertex
              end
            end
            @mouse_origin = origin
          end
        end
      elsif state_pick_u? || state_pick_v?
        edge = @ip_mouse.edge
        if edge && QuadFace.entity_in_quad?( edge )
          pts = edge.vertices.map { |v| v.position }
          unless QuadFace.dividing_edge?( edge )
            @mouse_edge = edge 
          end
        end
      end
      
      view.tooltip = @ip_mouse.tooltip
      view.invalidate
    end
    
    # @since 0.4.0
    def draw( view )
      @ip_mouse.draw( view ) if @ip_mouse.display? # <debug/>
      
      view.line_stipple = ''
      
      for i in ( 0..2 )
        polygons = @preview_quads[ i ]
        unless polygons.empty?
          view.drawing_color = CLR_MATRIX[ i ]
          view.draw( GL_TRIANGLES, polygons )
        end
      end
      
      if @mouse_edge
        view.drawing_color = CLR_MOUSE
        view.line_width = 3
        view.draw( GL_LINES, @mouse_edge.vertices.map { |v| v.position } )
      end
      if @mouse_origin
        view.line_width = 1
        view.draw_points( @mouse_origin.position, 8, TT::POINT_FILLED_SQUARE, CLR_MOUSE )
      end
      
      if @u_edge
        view.drawing_color = CLR_PICKED
        view.line_width = 3
        view.draw( GL_LINES, @u_edge.vertices.map { |v| v.position } )
      end
      if @v_edge
        view.drawing_color = CLR_PICKED
        view.line_width = 3
        view.draw( GL_LINES, @v_edge.vertices.map { |v| v.position } )
      end
      if @origin
        view.line_width = 1
        view.draw_points( @origin.position, 8, TT::POINT_FILLED_SQUARE, CLR_PICKED )
      end
      
      if @valid_pick
        points = @valid_pick.map { |e|
          e.vertices.map { |v| v.position }
        }.flatten
        view.drawing_color = CLR_VALID
        view.line_width = 3
        view.draw( GL_LINES, points )
      end
      
    end
    
    # @since 0.4.0
    def update_ui
      if state_pick_origin?
        Sketchup.status_text = %{Pick a vertex for origin or an edge for U direction.}
      elsif state_pick_u?
        Sketchup.status_text = %{Pick an edge for U direction.}
      elsif state_pick_v?
        Sketchup.status_text = %{Pick an edge for V direction.}
      end
    end
    
    # @since 0.4.0
    def state_pick_origin?
      @origin.nil? && @u_edge.nil? && @v_edge.nil?
    end
    
    # @since 0.4.0
    def state_pick_u?
      @origin && @u_edge.nil? && @v_edge.nil?
    end
    
    # @since 0.4.0
    def state_pick_v?
      @origin && @u_edge && @v_edge.nil?
    end
    
    # Tries to build a 2D grid from the quads. Such a grid can be used to
    # transfer mapping from one mesh to another.
    #
    # However, meshes with E and N poles will not be able to generate a 2D
    # grid. In such cases this method return nil.
    #
    # @param [Array<Hash>] mapping_set
    #
    # @return [Hash,Nil]
    # @since 0.4.0
    def get_mapping_grid( mapping_set )
      grid = {}
      for data in mapping_set
        coordinate = data[ :origin ]
        return nil if grid[ coordinate ]
        grid[ coordinate ] = data
      end
      grid
    end
    
    # Maps each quad induvidually without any regard to continuity between the
    # quads.
    #
    # @param [Array<Hash>] mapping_set
    # @param [Float,Length] u_scale
    # @param [Float,Length] v_scale
    #
    # @return [Boolean]
    # @since 0.4.0
    def map_mesh_induvidually( mapping_set, u_scale = 1.0, v_scale = 1.0 )
      model = Sketchup.active_model
      material = model.materials.current
      if material && !TT::Material.in_model?( material )
        UI.messagebox( 'Selected material is not added to the model yet.' )
        return false
      end
      Sketchup.status_text = 'UV Mapping Quads...'
      for data in mapping_set
        quad = data[ :quad ]
        u1 = data[ :u_edge ]
        v1 = data[ :v_edge ]
        u2 = data[ :u2_edge ]
        v2 = data[ :v2_edge ]
        origin = data[ :origin ]
        # Vertices - Counter-clockwise order from origin
        vertex1 = origin
        vertex2 = u1.other_vertex( vertex1 )
        vertex3 = v2.other_vertex( vertex2 )
        vertex4 = v1.other_vertex( vertex1 )
        # Mapping Scale
        if u_scale.is_a?( Length )
          u = u1.length / u_scale
          v = v1.length / v_scale
        else
          u = u_scale
          v = v_scale
        end
        # UV mapping
        mapping = {
          vertex1 => [0,0],
          vertex2 => [u,0],
          vertex3 => [u,v],
          vertex4 => [0,v]
        }
        quad.uv_set( material, mapping )
      end
      true
    end
    
    # Maps the set of quads based on relative ratios, keeping continutity
    # between the quads.
    #
    # @param [Array<Hash>] mapping_set
    # @param [Float] u_scale
    # @param [Float] v_scale
    #
    # @return [Boolean]
    # @since 0.4.0
    def map_grid_by_ratio( mapping_set, u_scale, v_scale )
      model = Sketchup.active_model
      material = model.materials.current
      if material && !TT::Material.in_model?( material )
        UI.messagebox( 'Selected material is not added to the model yet.' )
        return false
      end
      Sketchup.status_text = 'UV Mapping Quads...'
      for data in mapping_set
        quad = data[ :quad ]
        u = data[ :u_edge ]
        v = data[ :v_edge ]
        u2 = data[ :u2_edge ]
        v2 = data[ :v2_edge ]
        origin = data[ :origin ]
        x, y = data[ :coordinate ]
        # Vertices - Counter-clockwise order from origin
        vertex1 = origin
        vertex2 = u.other_vertex( vertex1 )
        vertex3 = v2.other_vertex( vertex2 )
        vertex4 = v.other_vertex( vertex1 )
        # UV data
        u1 = x * u_scale
        u2 = ( x + 1 ) * u_scale
        v1 = y * v_scale
        v2 = ( y + 1 ) * v_scale
        next unless u1 && u2 && v1 && v2 # DEBUG
        # UV mapping
        mapping = {
          vertex1 => [ u1, v1 ],
          vertex2 => [ u2 ,v1 ],
          vertex3 => [ u2 ,v2 ],
          vertex4 => [ u1 ,v2 ]
        }
        quad.uv_set( material, mapping )
      end
      true
    end
    
    # Maps the set of quads based on absolute length along the U and V axes,
    # keeping continutity between the quads.
    #
    # @param [Array<Hash>] mapping_set
    # @param [Length] u_scale
    # @param [Length] v_scale
    #
    # @return [Boolean]
    # @since 0.4.0
    def map_grid_by_length( mapping_set, u_mapping, v_mapping )
      model = Sketchup.active_model
      material = model.materials.current
      if material && !TT::Material.in_model?( material )
        UI.messagebox( 'Selected material is not added to the model yet.' )
        return false
      end
      Sketchup.status_text = 'UV Mapping Quads...'
      for data in mapping_set
        quad = data[ :quad ]
        u = data[ :u_edge ]
        v = data[ :v_edge ]
        u2 = data[ :u2_edge ]
        v2 = data[ :v2_edge ]
        origin = data[ :origin ]
        x, y = data[ :coordinate ]
        # Vertices - Counter-clockwise order from origin
        vertex1 = origin
        vertex2 = u.other_vertex( vertex1 )
        vertex3 = v2.other_vertex( vertex2 )
        vertex4 = v.other_vertex( vertex1 )
        # UV data
        u1 = u_mapping[ x ]
        u2 = u_mapping[ x + 1 ]
        v1 = v_mapping[ y ]
        v2 = v_mapping[ y + 1 ]
        # Skip quad if the quad coordiantes exceeds the mapping grid's size.
        next unless u1 && u2 && v1 && v2
        # UV mapping
        mapping = {
          vertex1 => [ u1, v1 ],
          vertex2 => [ u2 ,v1 ],
          vertex3 => [ u2 ,v2 ],
          vertex4 => [ u1 ,v2 ]
        }
        quad.uv_set( material, mapping )
      end
      true
    end
    
    # Traverse the connected mesh of the picked origin and attempts to map it
    # to a 2D grid.
    #
    # @return [Array<Hash>]
    # @since 0.4.0
    def compute_mapping
      # Prepare origin quad
      u_quads = PLUGIN.connected_quad_faces( @u_edge )
      origin_quad = u_quads.find { |quad| quad.edges.include?( @v_edge ) }
      origin = {
        :quad => origin_quad,
        :origin => @origin,
        :u_edge => @u_edge,
        :v_edge => @v_edge,
        :u2_edge => origin_quad.opposite_edge( @u_edge ),
        :v2_edge => origin_quad.opposite_edge( @v_edge ),
        :coordinate => [ 0, 0 ]
      }
      
      quads = {} # face => QuadFace
      stack = [ origin ]
      stack_negative = []
      mapped = []
      
      # (!) Progressbar ( Status update )
      until stack.empty?
        #TT.debug 'Stack Shift'
        data = stack.shift
        quad = data[ :quad ]
        coordinate = data[ :coordinate ] 
        invalid = false
        # Contrain quad mapping if contraint is present
        unless @contraints.empty?
          invalid = true unless quad.faces.all? { |face| @contraints[ face ] }
        end
        # Prevent parsing quads more than once.
        if invalid || quad.faces.any? { |face| quads[ face ] }
          # If the face is invalid and the look skips to the next iteration the
          # stack needs to be refilled if it's empty.
          if stack.empty?
            #TT.debug '> Break Refill'
            stack = stack_negative.dup
            stack_negative.clear
          end
          next
        end
        # Map faces to quads
        for face in quad.faces
          quads[ face ] = quad
        end
        # Add to mapping stack
        mapped << data
        # Preview
        x, y = coordinate
        i = ( ( x % 3 ) + ( y % 3 ) ) % 3
        mesh = quad.mesh
        triangles = ( 1..mesh.count_polygons ).map { |index|
          mesh.polygon_points_at( index )
        }.flatten
        @preview_quads[ i ].concat( triangles )
        # Connected Edges
        u = data[ :u_edge ]
        v = data[ :v_edge ]
        u2 = data[ :u2_edge ]
        v2 = data[ :v2_edge ]
        # Process Quads
        #   Add results for increasing co-ordinates first in the stack and
        #   decreasing to the end of the stack.
        #
        #   This ensures that in looping surfaces the coordinates only increases
        #   from the origin.
        for edge in [ u2, v2 ]
          item = next_quad( data, edge, quads )
          stack << item if item
        end
        for edge in [ u, v ]
          item = next_quad( data, edge, quads )
          stack_negative << item if item
        end
        # Refill the stack
        if stack.empty?
          #TT.debug '> Refill Last'
          stack = stack_negative.dup
          stack_negative.clear
        end
      end
      mapped
    end
    
    # Determines the next quad based on the source.
    #
    # @param [Hash] data Origin dataset connected to +common_edge+.
    # @param [Sketchup::Edge] common_edge
    # @param [Array<Sketchup::Face>] processed Already processed faces.
    #
    # @return [Hash,False]
    # @since 0.4.0
    def next_quad( data, common_edge, processed )
      quadface = PLUGIN.connected_quads( common_edge ).find { |quad|
        !quad.faces.any? { |face| processed[ face ] }
      }
      return false unless quadface
      
      origin = data[ :origin ]
      quad = data[ :quad ]
      u = data[ :u_edge ]
      v = data[ :v_edge ]
      u2 = data[ :u2_edge ]
      v2 = data[ :v2_edge ]
      x, y = data[ :coordinate ]
      
      if common_edge == u || common_edge == u2
        # Shares U Edge
        next_x = x
        if common_edge == u
          next_u = quadface.opposite_edge( common_edge )
          next_y = y - 1
        else
          next_u = common_edge
          next_y = y + 1
        end
        next_v = quadface.edges.find { |e|
          e != common_edge && TT::Edges.common_vertex( e, v )
        }
      else
        # Shares V Edge
        next_y = y
        if common_edge == v
          next_v = quadface.opposite_edge( common_edge )
          next_x = x - 1
        else
          next_v = common_edge
          next_x = x + 1
        end
        next_u = quadface.edges.find { |e|
          e != common_edge && TT::Edges.common_vertex( e, u )
        }
      end
      
      next_u2 = quadface.opposite_edge( next_u )
      next_v2 = quadface.opposite_edge( next_v )
      next_origin = TT::Edges.common_vertex( next_u, next_v )

      item = {
        :quad => quadface,
        :origin => next_origin,
        :u_edge => next_u,
        :v_edge => next_v,
        :u2_edge => next_u2,
        :v2_edge => next_v2,
        :coordinate => [ next_x, next_y ]
      }
    end
    
    # @param [Hash] data
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 0.4.0
    def ordered_vertices( data )
      vertices = []
      u1 = data[ :u_edge ]
      v1 = data[ :v_edge ]
      u2 = data[ :u2_edge ]
      v2 = data[ :v2_edge ]
      vertices << TT::Edges.common_vertex( u1, v1 )
      vertices << u1.other_vertex( vertices[0] )
      vertices << v1.other_vertex( vertices[0] )
      vertices << u2.other_vertex( vertices[2] )
      vertices
    end
    
  end # class UV_GridTool
  
end # module