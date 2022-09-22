#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'delegate.rb'

require 'TT_QuadFaceTools/dpi/inputpoint'
require 'TT_QuadFaceTools/dpi/pick_helper'
require 'TT_QuadFaceTools/dpi/view'


module TT::Plugins::QuadFaceTools
# Utility module for computing unit conversions based on monitor DPI.
module DPI

  # To test scaling on a "normal" DPI monitor, use this method to force
  # scaling. SketchUp needs to be restarted for it to take full effect.
  #
  #     TT::Plugins::QuadFaceTools::DPI.debug_scale(2.0)
  #     TT::Plugins::QuadFaceTools::DPI.debug_scale(nil)
  #
  # @param [Float, nil] scale
  def self.debug_scale(scale)
    if scale
      PLUGIN.settings[:debug_force_high_dpi] = true
      set_scaling(scale)
    else
      PLUGIN.settings[:debug_force_high_dpi] = false
    end
  end

  def self.debug_scale?
    PLUGIN.settings[:debug_force_high_dpi]
  end

  # Scaling Units

  # Sets the manual scaling used for older SketchUp versions that doesn't have
  # UI.scale_factor.
  #
  # @param [Float, nil] scale
  def self.set_scaling(scale)
    @tr_scale_to_device = nil
    @tr_scale_to_logical = nil
    PLUGIN.settings[:dpi_scale_factor] = scale
  end

  if PLUGIN.settings[:debug_force_high_dpi]
    # @return [Float]
    def self.scale_factor
      PLUGIN.settings[:dpi_scale_factor]
    end
  else
    # @return [Float]
    def self.scale_factor
      UI.scale_factor
    end
  end

  # @param [Numeric] logical_unit
  # @return [Float]
  def self.to_device(logical_unit)
    logical_unit * DPI.scale_factor
  end

  # @param [Numeric] device_unit
  # @return [Float]
  def self.to_logical(device_unit)
    device_unit / DPI.scale_factor
  end

  # Converts from device pixels to logical pixels.
  #
  # @param [Float] x
  # @param [Float] y
  # @return [Array(Float, Float)]
  def self.logical_pixels(x, y)
    s = DPI.scale_factor
    [x / s, y / s]
  end

  # Converts from logical pixels to device pixels.
  #
  # @param [Float] x
  # @param [Float] y
  # @return [Array(Float, Float)]
  def self.device_pixels(x, y)
    s = DPI.scale_factor
    [x * s, y * s]
  end

  # Transformation the scales from logical units to device units.
  #
  # @return [Geom::Transformation]
  def self.scale_to_device_transform
    @tr_scale_to_device ||= Geom::Transformation.scaling(scale_factor,
                                                         scale_factor,
                                                         scale_factor)
    @tr_scale_to_device
  end

  # Transformation the scales from device units to logical units.
  #
  # @return [Geom::Transformation]
  def self.scale_to_logical_transform
    @tr_scale_to_logical ||= scale_to_device_transform.inverse
    @tr_scale_to_logical
  end

  # Scaling line width
  def self.force_scale_factor?
    PLUGIN.settings[:debug_force_high_dpi] && UI.scale_factor == 1.0
  end

  if self.force_scale_factor?
    # @param [Numeric] width
    # @return [Numeric]
    def self.scale_line_width(width)
      to_device(width)
    end
  else
    # @param [Numeric] width
    # @return [Numeric]
    def self.scale_line_width(width)
      # SketchUp 17 scales line weights automatically.
      width
    end
  end

end
end # module
