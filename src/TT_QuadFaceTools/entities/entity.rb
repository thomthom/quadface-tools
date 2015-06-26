#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_Lib2/core'


module TT::Plugins::QuadFaceTools
class Entity

  def initialize
    @faces = nil # TODO: Move to QuadFace - or other Face base class.
  end

  # TODO: Move to QuadFace - or other Face base class.
  # @return [Float]
  def area
    @faces.inject(0.0) { |sum, face| sum + face.area }
  end

  # TODO: Move to QuadFace - or other Face base class.
  # @return [Sketchup::Material]
  def back_material
    @faces[0].back_material
  end

  # TODO: Move to QuadFace - or other Face base class.
  # @param [Sketchup::Material] new_material
  #
  # @return [Sketchup::Material]
  def back_material=(new_material)
    @faces.each { |face|
      face.back_material = new_material
    }
  end

  # @return [Array<Sketchup::Face>]
  def faces
    @faces.dup
  end

  # TODO: Move to QuadFace - or other Face base class.
  # @param [Sketchup::Face] face
  #
  # @return [Boolean]
  def include?(face)
    @faces.include?(face)
  end

  # @return [String]
  def inspect
    name = self.class.name.split('::').last
    hex_id = TT.object_id_hex( self )
    "#<#{name}:#{hex_id}>"
  end

  # @return [Sketchup::Material]
  def material
    @faces[0].material
  end

  # @param [Sketchup::Material] new_material
  #
  # @return [Sketchup::Material]
  def material=(new_material)
    @faces.each { |face|
      face.material = new_material
    }
  end

  # @return [Sketchup::Model]
  def model
    @faces[0].model
  end

  # TODO: Move to QuadFace - or other Face base class.
  # @return [Geom::Vector3d]
  def normal
    x = y = z = 0.0
    @faces.each { |face|
      vector = face.normal
      x += vector.x
      y += vector.y
      z += vector.z
    }
    num_faces = @faces.size
    x /= num_faces
    y /= num_faces
    z /= num_faces
    Geom::Vector3d.new(x, y, z)
  end

  # @return [Sketchup::Entities]
  def parent
    @faces[0].parent
  end

  # TODO: Move to QuadFace - or other Face base class.
  def reverse!
    @faces.each { |face|
      face.reverse!
    }
    self
  end

end # class
end # module
