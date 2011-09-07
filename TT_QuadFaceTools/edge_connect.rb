#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  
  # @todo Optimize. Splitting the geometry is very slow!
  #
  # @since 0.3.0
  class EdgeConnect
    
    # @since 0.3.0
    attr_reader( :cut_edges, :segments, :pinch )
    
    # @since 0.3.0
    def initialize(
        cut_edges,
        segments = 1,
        pinch = 0,
        entities = Sketchup.active_model.active_entities
      )
      @cut_edges = cut_edges
      @entities = entities
      @quads = []
      @segments = segments
      @pinch = pinch # (-100..100 )
      @preview_lines = []
      collect_quads()
      update_draw_cache()
    end
    
    # @param [Array<Sketchup::Edges>] new_edges
    #
    # @return [Integer]
    # @since 0.3.0
    def cut_edges=( new_edges )
      @cut_edges = new_edges
      collect_quads()
      update_draw_cache()
      @cut_edges.size
    end
    
    # @param [Integer] new_segments
    #
    # @return [Integer]
    # @since 0.3.0
    def segments=( new_segments )
      @segments = new_segments
      update_draw_cache()
      @segments
    end
    
    # @param [Integer] new_pinch ( -100..100 )
    #
    # @return [Integer]
    # @since 0.3.0
    def pinch=( new_pinch )
      @pinch = new_pinch
      update_draw_cache()
      @pinch
    end
    
    # @since 0.3.0
    def draw( view )
      unless @preview_lines.empty?
        splits = @preview_lines.flatten
        splits2d = splits.map { |pt| view.screen_coords( pt ) }
        
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = [ 0, 128, 0 ]
        view.draw( GL_LINES, splits )
        
        view.line_stipple = '-'
        view.line_width = 1
        view.draw2d( GL_LINES, splits2d )
      end
    end
    
    # @return [Array<Sketchup::Edge>]
    # @since 0.3.0
    def connect!
      split_quads( @quads, @cut_edges, @segments, @pinch )
    end
    
    private
    
    # @return [Integer] Number of quads found.
    # @since 0.3.0
    def collect_quads
      @quads.clear
      quadfaces = {}
      edges = @cut_edges
      for edge in edges
        for face in edge.faces
          next if quadfaces[ face ]
          next unless QuadFace.is?( face )
          quad = QuadFace.new( face )
          next unless ( quad.edges & edges ).size > 1
          @quads << quad
          for face in quad.faces
            quadfaces[ face ] = quad
          end
        end
      end
      @quads.size
    end

    # @since 0.3.0
    def update_draw_cache
      splits = []
      result = get_quad_splits( @quads, @cut_edges, @segments, @pinch )
      for quadface, data in result
        splits.concat( data[ :splits ] )
      end
      @preview_lines = splits
    end
    
    # @param [<Array<Geom::Point3d,Geom::Point3d>] line
    # @param [Array<Array<Float,Float>>] ratios
    #
    # @return [Array<Geom::Point3d>]
    # @since 0.3.0
    def split_edge( line, ratios )
      p1, p2 = line
      points = []
      for x, y in ratios
        points << Geom.linear_combination( x, p1, y, p2 )
      end
      points
    end
    
    # @param [Integer] splits
    # @param [Integer] pinch -100..100
    #
    # @return [Array<Array<Float,Float>>]
    # @since 0.3.0
    def split_ratios( splits, pinch = 0 )
      segments = splits + 1
      pinch_ratio = pinch / 100.0
      
      if pinch_ratio > 0.0 && splits > 1
        segment_length = 1.0 / segments
        r = segment_length * pinch_ratio
        start = segment_length - r
        t = r * 2
        length = segment_length + ( t / ( segments-2 ) )
      else
        pinch_length = 1.0 + pinch_ratio
        length = pinch_length / segments
        start = ( 1.0 - pinch_length ) / 2
        start += length
      end
      
      results = []
      splits.times { |i|
        x = start + ( length * i )
        y = 1.0 - x
        results << [ x, y ]
      }
      results
    end
    
    # @param [Array<QuadFace>] quads
    # @param [Array<Sketchup::Edge>] cut_edges
    # @param [Integer] splits
    # @param [Float] pinch
    #
    # @return [Hash]
    # @since 0.3.0
    def get_quad_splits( quads, cut_edges, splits, pinch )
      result = {}
      ratios = split_ratios( splits, pinch )
      for quad in quads
        result[ quad ] = {
          :splits => [],
          :polygons => []
        }
        props = result[ quad ]
        
        # Get selected edges in the order of the outer loop.
        selected = ( quad.outer_loop & cut_edges )
        
        # Map edges to sets of points for each split
        split_set = selected.map { |edge|
          line = quad.edge_positions( edge )
          split_edge( line, ratios )
        }
        
        # Map one half of the split to the next edge. This ensures T and X splits
        # are calculated.
        half_split = ( splits / 2.0 ).ceil # Round up to include centre
        split_set.each_with_index { |set, index|
          # Middle Segments.
          next_index = ( index + 1 ) % split_set.size
          next_set = split_set[ next_index ]
          half_split.times { |i|
            props[ :splits ] << [ set[i], next_set[-(i+1)] ]
          }
          
          # Work out the bordering polygons.
          edge = selected[ index ]
          next_edge = selected[ next_index ]
          polygon = []
          
          line1 = quad.edge_positions( edge )
          line2 = quad.edge_positions( next_edge )
          
          if quad.opposite_edge( edge ) == next_edge
            # Across
            polygon = [
              line1[1],
              line2[0],
              next_set[-1],
              set[0]
            ]
          else
            if TT::Edges.common_vertex( edge, next_edge ).position == line1[1]
              # Inner corner
              polygon = [
                line1[1],
                next_set[-1],
                set[0]
              ]
            else
              # Outer corner
              v1 = TT::Edges.common_vertex( edge, next_edge )
              v2 = edge.other_vertex( v1 )
              v3 = next_edge.other_vertex( v1 )
              v4 = ( quad.vertices - [ v1, v2, v3 ] )[0]
              polygon = [
                set[0],
                next_set[-1],
                v3.position,
                v4.position,
                v2.position
              ]
            end
          end
          
          props[ :polygons ] << polygon
        }
      end
      result
    end
    
    # @param [Array<QuadFace>] quads
    # @param [Array<Sketchup::Edge>] cut_edges
    # @param [Integer] splits
    # @param [Float] pinch
    #
    # @return [Array<Sketchup::Edge>]
    # @since 0.3.0
    def split_quads( quads, cut_edges, splits, pinch )
      entities = @entities
      new_edges = []
      result = get_quad_splits( quads, cut_edges, splits, pinch )
      progress = TT::Progressbar.new( result, 'Splitting QuadFaces' )
      for quadface, data in result
        lines = data[ :splits ]
        
        # Determine the shape of the split
        set_size = ( splits / 2.0 ).ceil
        set_count = lines.size / set_size
        # 2 = Across or Corner
        # 3 = T junction
        # 4 = X junction
        odd = splits % 2 == 1
        
        # Erase original
        quadface.erase!
        
        # <debug>
        #lines.each_with_index { |line, index|
        #  pt1, pt2 = line
        #  entities.add_text( "#{index.to_s} (1)", pt1, [2,2,2] )
        #  entities.add_text( "#{index.to_s} (2)", pt2, [2,2,2] )
        #}
        # </debug>
        
        # Edges
        # These are created first so they can later be selected.
        for line in lines
          edge = entities.add_line( line )
          new_edges << edge
        end
        
        # Face Strips
        (0...set_count).each { |x|
          (0...set_size-1).each { |y|
            i = ( x * set_size ) + y
            j = i + 1
            pts = lines[i] + lines[j].reverse
            PLUGIN.fill_face( entities, pts )
          }
        }
        
        # Fill edges and centre holes
        # Faces ( 2 edges )
        if set_count == 2
          # Centre Holes
          unless odd
            line1 = lines[set_size-1]
            line2 = lines[-1]
            pts = line1 + line2
            PLUGIN.fill_face( entities, pts )
          end
        # Faces ( 3 edges )
        elsif set_count == 3
          # Centre Holes
          if odd
            pt1 = lines[set_size-1][0]
            pt2 = lines[set_size+set_size-1][0]
            pt3 = lines[-1][0]
            entities.add_face( pt1, pt2, pt3 )
          else
            line1 = lines[set_size-1]
            line2 = lines[set_size+set_size-1]
            line3 = lines[-1]
            pts = line1 + line2 + line3
            if TT::Geom3d.planar_points?( pts )
              entities.add_face( pts )
            else
              f1 = entities.add_face( pts[0], pts[2], pts[1] )
              f2 = entities.add_face( pts[0], pts[4], pts[5] )
              f3 = entities.add_face( pts[2], pts[3], pts[4] )
              f4 = entities.add_face( pts[0], pts[2], pts[4] )
              f4.edges.each { |e|
                e.soft = true
                e.smooth = true
              }
            end # planar_points?
          end
        # Faces ( 4 edges )
        elsif set_count == 4
          # Centre Holes
          if odd
            pt1 = lines[set_size-1][0]
            pt2 = lines[set_size+set_size-1][0]
            pt3 = lines[set_size+set_size+set_size-1][0]
            pt4 = lines[-1][0]
            # Points are always planar. (?)
            entities.add_face( pt1, pt2, pt3, pt4 )
          else
            line1 = lines[set_size-1]
            line2 = lines[set_size+set_size-1]
            line3 = lines[set_size+set_size+set_size-1]
            line4 = lines[-1]
            pts = line1 + line2 + line3 + line4
            if TT::Geom3d.planar_points?( pts )
              entities.add_face( pts )
            else
              f1 = entities.add_face( pts[0], pts[1], pts[2] )
              f2 = entities.add_face( pts[2], pts[3], pts[4] )
              f3 = entities.add_face( pts[4], pts[5], pts[6] )
              f4 = entities.add_face( pts[6], pts[7], pts[0] )
              f5 = entities.add_face( pts[0], pts[2], pts[4] )
              f6 = entities.add_face( pts[4], pts[6], pts[0] )
              ( f5.edges + f6.edges ).each { |e|
                e.soft = true
                e.smooth = true
              }
            end # planar_points?
          end
          
        end
        
        # Bordering polygons
        for polygon in data[ :polygons ]
          # <debug>
          #polygon.each_with_index { |pt, index|
          #  entities.add_text( "#{index.to_s}", pt, [2,2,2] )
          #}
          # </debug>
          if polygon.size == 5 && !TT::Geom3d.planar_points?( polygon )
            pt1, pt2, pt3, pt4, pt5 = polygon
            f1 = entities.add_face( pt1, pt2, pt4 )
            f2 = entities.add_face( pt1, pt4, pt5 )
            f3 = entities.add_face( pt2, pt3, pt4 )
            edges = ( f1.edges & f2.edges ) + ( f1.edges & f3.edges )
            edges.each { |e|
              e.soft = true
              e.smooth = true
            }
          else
            PLUGIN.fill_face( entities, polygon )
          end
        end
        
        progress.next
      end
      new_edges
    end
    
  end # class EdgeConnect

end # module