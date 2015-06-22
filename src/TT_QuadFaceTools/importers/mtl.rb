#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
class MtlParser

  Material = Struct.new(:name, :color, :alpha, :texture)

  # @param [Sketchup::Model] model
  # @param [String] base_path
  def initialize(model, base_path)
    @model = model
    @base_path = base_path
    @materials = []
    @sketchup_materials = {}
  end

  # @return [Integer]
  def loaded_materials
    @materials.size
  end

  # @return [Integer]
  def used_materials
    @sketchup_materials.size
  end

  # @param [String] filename
  #
  # @return [Boolean]
  def read(filename)
    unless File.exist?(filename)
      puts "unable to find file: #{filename}"
      return false
    end
    # @see http://paulbourke.net/dataformats/mtl/
    File.open(filename, 'r') { |file|
      file.each_line { |line|
        # Filter out comments.
        next if line.start_with?('#')
        # Filter out empty lines.
        next if line.strip.empty?
        # Parse the line data and extract the line token.
        data = line.split(/\s+/)
        token = data.shift
        case token
        when 'newmtl'
          @materials << Material.new(data[0])
        when 'Kd'
          current_material.color = parse_color(data)
        when 'd'
          current_material.alpha = parse_alpha(data)
        when 'map_Kd'
          begin
            current_material.texture = parse_texture(data)
          rescue RuntimeError # TODO: Add custom error type.
            # Fall back to using the whole line as the filename. Version 0.8
            # exported MTL files with spaces if the OBJ file had spaces.
            result = line.match(/map_Kd\s+(.+)/)
            raise if result.nil?
            data = [result[1]]
            puts "falling back to trying: #{data[0]}"
            current_material.texture = parse_texture(data)
          end
        else
          # Ignore these properties as they cannot be represented in SketchUp.
          #puts "ignoring token: #{token}" # TODO: Log.
          next
        end
      }
    }
    true
  end

  # @param [String] material_name
  #
  # @return [Sketchup::Material, Nil]
  def get(material_name)
    material = @sketchup_materials[material_name]
    if material.nil?
      definition = @materials.find { |m| m.name == material_name }
      puts "material not found: #{material_name}" if definition.nil?
      return nil if definition.nil?
      material = @model.materials.add(material_name)
      material.color = definition.color if definition.color
      material.alpha = definition.alpha if definition.alpha
      material.texture = definition.texture if definition.texture
      @sketchup_materials[material_name] = material
    end
    material
  end

  private

  # @param [Numeric] value
  # @param [Numeric] minimum
  # @param [Numeric] maximum
  #
  # @return [Numeric]
  def clamp(value, minimum, maximum)
    [[minimum, value].max, maximum].min
  end

  # @return [Material, Nil]
  def current_material
    raise 'no materials defined' if @materials.empty?
    @materials.last
  end

  # @param [Array<String>] data
  #
  # @return [Float]
  def parse_alpha(data)
    case data[0]
    when '-halo'
      raise 'unsupported dissolve definition'
    else
      clamp(data[0].to_f, 0.0, 1.0)
    end
  end

  # @param [Array<String>] data
  #
  # @return [Sketchup::Color]
  def parse_color(data)
    case data[0]
    when 'spectral', 'xyz'
      # TODO: Support CIEXYZ color space?
      raise 'unsupported color definition'
    else
      r, g, b = parse_rgb(data)
      Sketchup::Color.new(r, g, b)
    end
  end

  # @param [Array<String>] data
  #
  # @return [Array<Integer>]
  def parse_rgb(data)
    raise 'need at least one component' if data.empty?
    rgb = data.map { |n| (255.0 * clamp(n.to_f, 0.0, 1.0)).to_i }
    # If only r is specified, then g, and b are assumed to be equal to r.
    until rgb.size >= 2
      rgb << rgb.first
    end
    rgb
  end

  # @param [Array<String>] data
  #
  # @return [String]
  def parse_texture(data)
    if data.size == 1
      filename = data[0]
      unless File.exist?(filename)
        filename = File.join(@base_path, filename)
      end
      File.expand_path(filename)
    else
      # TODO: Ignore options.
      p data
      raise 'unsupported texture definition'
    end
  end

end # class
end # module
