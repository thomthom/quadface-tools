#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
class MtlParser

  attr_accessor :index_base

  Material = Struct.new(:name, :color, :alpha, :texture)

  def initialize(model, base_path)
    @model = model
    @base_path = base_path
    @materials = []
    @sketchup_materials = {}
  end

  def loaded_materials
    @materials.size
  end

  def used_materials
    @sketchup_materials.size
  end

  def read(filename)
    unless File.exist?(filename)
      puts "unable to find file: #{filename}"
      return false
    end
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
          current_material.texture = parse_texture(data)
        else
          # Ignore these properties as they cannot be represented in SketchUp.
          puts "ignoring token: #{token}" # TODO: Remove.
          next
        end
      }
    }
    true
  end

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

  def clamp(value, minimum, maximum)
    [[minimum, value.to_f].max, maximum].min
  end

  def current_material
    @materials.last
  end

  def parse_alpha(data)
    case data[0]
    when '-halo'
      raise 'unsupported dissolve definition'
    else
      clamp(data[0].to_f, 0.0, 1.0)
    end
  end

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

  def parse_rgb(data)
    raise 'need at least one component' if data.empty?
    rgb = data.map { |n| (255.0 * clamp(n.to_f, 0.0, 1.0)).to_i }
    # If only r is specified, then g, and b are assumed to be equal to r.
    until rgb.size >= 2
      rgb << rgb.first
    end
    rgb
  end

  def parse_texture(data)
    if data.size == 1
      filename = data[0]
      unless File.exist?(filename)
        filename = File.join(@base_path, filename)
      end
      File.expand_path(filename)
    else
      # TODO: Ignore options.
      raise 'unsupported texture definition'
    end
  end

end # class
end # module
