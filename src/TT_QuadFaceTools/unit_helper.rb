#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
module UnitHelper

  # Matches Sketchup.active_model.options['UnitsOptions']['LengthUnit']
  UNIT_MODEL       = -1 # Not a SketchUp value
  UNIT_INCHES      = Length::Inches
  UNIT_FEET        = Length::Feet
  UNIT_MILLIMETERS = Length::Millimeter
  UNIT_CENTIMETERS = Length::Centimeter
  UNIT_METERS      = Length::Meter
  UNIT_KILOMETERS  = 5 # Not a SketchUp value

  # @param [Integer] unit
  #
  # @return [String]
  def unit_to_string(unit)
    case unit
    when UNIT_KILOMETERS
      'Kilometers'
    when UNIT_METERS
      'Meters'
    when UNIT_CENTIMETERS
      'Centimeters'
    when UNIT_MILLIMETERS
      'Millimeters'
    when UNIT_FEET
      'Feet'
    when UNIT_INCHES
      'Inches'
    when UNIT_MODEL
      'Model Units'
    else
      raise ArgumentError, 'Invalid unit type.'
    end
  end

  # @param [String] string
  #
  # @return [Integer]
  def string_to_unit(string)
    case string
    when 'Kilometers'
      UNIT_KILOMETERS
    when 'Meters'
      UNIT_METERS
    when 'Centimeters'
      UNIT_CENTIMETERS
    when 'Millimeters'
      UNIT_MILLIMETERS
    when 'Feet'
      UNIT_FEET
    when 'Inches'
      UNIT_INCHES
    when 'Model Units'
      UNIT_MODEL
    else
      raise ArgumentError, 'Invalid unit string.'
    end
  end

  # @param [Integer] unit
  #
  # @return [Float]
  def inch_to_unit_ratio(unit)
    if unit == UNIT_MODEL
      unit = Sketchup.active_model.options['UnitsOptions']['LengthUnit']
    end
    case unit
    when UNIT_KILOMETERS
      0.0000254
    when UNIT_METERS
      0.0254
    when UNIT_CENTIMETERS
      2.54
    when UNIT_MILLIMETERS
      25.4
    when UNIT_FEET
      1.0 / 12.0
    when UNIT_INCHES
      1.0
    else
      raise ArgumentError, 'Invalid unit type.'
    end
  end

  # @param [Integer] unit
  #
  # @return [Float]
  def unit_to_inch_ratio(unit)
    1.0 / inch_to_unit_ratio(unit)
  end

  # @param [Numeric] value
  # @param [Integer] unit
  #
  # @return [Length]
  def convert_to_length(value, unit)
    scale = unit_to_inch_ratio(unit)
    (value.to_f * scale).to_l
  end

end # module
end # module
