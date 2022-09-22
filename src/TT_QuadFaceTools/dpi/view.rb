#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_QuadFaceTools/dpi/inputpoint'
require 'TT_QuadFaceTools/dpi/pick_helper'
require 'TT_QuadFaceTools/dpi'


module TT::Plugins::QuadFaceTools
# Shim that takes care of dealing monitor DPI.
#
# The users of this class work with logical units and they are automatically
# converted to device pixels for the API to consume where appropriate.
class HighDpiView

  attr_reader :view

  # @param [Sketchup::View] view
  def initialize(view)
    raise TypeError, view.class.name unless view.is_a?(Sketchup::View)
    @view = view
  end

  # @return [Array(Float, Float)]
  def center
    logical_pixels(*@view.center)
  end

  # @param [Integer] index
  # @return [Array(Float, Float)]
  def corner(index)
    logical_pixels(*@view.corner(index))
  end

  # @overload draw2d(openglenum, points)
  #   @param [Integer] openglenum
  #   @param [Array<Geom::Point3d>] points
  #
  # @overload draw2d(openglenum, *points)
  #   @param [Integer] openglenum
  #   @param [Array<Geom::Point3d>] points
  def draw2d(openglenum, *args)
    points = (args.size == 1 && args[0].is_a?(Enumerable)) ? args[0] : args
    scaled_points = points.map { |point|
      point.transform(DPI.scale_to_device_transform)
    }
    @view.draw2d(openglenum, scaled_points)
  end

  # @param [Geom::Point3d] point
  # @param [String] text
  # @param [Hash] options
  def draw_text(point, text, options = {})
    origin = point.transform(DPI.scale_to_device_transform)
    if @view.method(:draw_text).arity == -1
      scaled_options = options.dup
      scaled_options[:size] ||= 10
      scaled_options[:size] *= DPI.scale_factor
      @view.draw_text(origin, text, scaled_options)
    else
      @view.draw_text(origin, text)
    end
  end

  # @overload lock_inference
  #
  # @overload lock_inference(inputpoint)
  #   @param [Sketchup::InputPoint, HighDpiInputPoint] inputpoint
  #
  # @overload lock_inference(inputpoint1, inputpoint2)
  #   @param [Sketchup::InputPoint, HighDpiInputPoint] inputpoint1
  #   @param [Sketchup::InputPoint, HighDpiInputPoint] inputpoint2
  #
  # @return [Boolean]
  def lock_inference(*args)
    args[0] = args[0].__getobj__ if args.size >= 1 && args[0].is_a?(HighDpiInputPoint)
    args[1] = args[1].__getobj__ if args.size >= 2 && args[1].is_a?(HighDpiInputPoint)
    @view.lock_inference(*args)
  end

  # @overload inputpoint(x, y)
  #   @param [Integer] x
  #   @param [Integer] y
  #
  # @overload inputpoint(x, y, inputpoint)
  #   @param [Integer] x
  #   @param [Integer] y
  #   @param [Sketchup::InputPoint, HighDpiInputPoint] inputpoint
  #
  # @return [HighDpiInputPoint]
  def inputpoint(*args)
    args[0] *= DPI.scale_factor # x
    args[1] *= DPI.scale_factor # y
    args[2] = args[2].__getobj__ if args.size >= 3 && args[2].is_a?(HighDpiInputPoint)
    ip = @view.inputpoint(*args)
    HighDpiInputPoint.new(ip)
  end

  # @param [Float] width
  def line_width=(width)
    @view.line_width = DPI.scale_line_width(width)
  end

  # @overload pick_helper
  #
  # @overload pick_helper(x, y, aperture = 0)
  #   @param [Integer] x
  #   @param [Integer] y
  #   @param [Integer] aperture
  #
  # @return [HighDpiPickHelper]
  def pick_helper(*args)
    args[0] *= DPI.scale_factor if args.size >= 1 # x
    args[1] *= DPI.scale_factor if args.size >= 2 # y
    HighDpiPickHelper.new(@view.pick_helper(*args))
  end

  # @param [Integer] x
  # @param [Integer] y
  # @return [Array(Geom::Point3d, Geom::Vector3d)]
  def pickray(x, y)
    @view.pickray(*DPI.device_pixels(x, y))
  end

  # @param [Integer] size
  # @param [Geom::Point3d] point
  # @return [Geom::Point3d]
  def pixels_to_model(size, point)
    if DPI.force_scale_factor?
      @view.pixels_to_model(DPI.to_device(size), point)
    else
      # It appeara that the internal function the API calls take the
      # scaling factor into account as of SU2017.
      @view.pixels_to_model(size, point)
    end
  end

  # @param [Geom::Point3d] point
  # @return [Geom::Point3d] # Screen coordinate
  def screen_coords(point)
    @view.screen_coords(point).transform(DPI.scale_to_logical_transform)
  end

  # @return [Float]
  def vpwidth
    DPI.to_logical(@view.vpwidth)
  end

  # @return [Float]
  def vpheight
    DPI.to_logical(@view.vpheight)
  end

  def method_missing(method_sym, *args, &block)
    @view.send(method_sym, *args, &block)
  end

  def respond_to_missing?(method_name, *args)
    @view.respond_to?(method_name) || super
  end

end # class
end # module
