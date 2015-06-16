#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
class ObjImporter < Sketchup::Importer

  module ImportResult
    SUCCESS = 0
    FAILURE = 1
  end

  # This method is called by SketchUp to determine the description that
  # appears in the File > Import dialog's pulldown list of valid
  # importers.
  #
  # @return [String]
  def description
    "OBJ Files - #{PLUGIN_NAME} (*.obj)"
  end

  # This method is called by SketchUp to determine what file extension
  # is associated with your importer.
  #
  # @return [String]
  def file_extension
    'obj'
  end

  # This method is called by SketchUp to get a unique importer id.
  #
  # @return [String]
  def id
    'com.sketchup.importers.obj_quadfacetools'
  end

  # This method is called by SketchUp to determine if the "Options"
  # button inside the File > Import dialog should be enabled while your
  # importer is selected.
  #
  # @return [Boolean]
  def supports_options?
    false
  end

  # This method is called by SketchUp when the user clicks on the
  # "Options" button inside the File > Import dialog. You can use it to
  # gather and store settings for your importer.
  #
  # @return [Nil]
  def do_options
    nil
  end

  # This method is called by SketchUp after the user has selected a file
  # to import. This is where you do the real work of opening and
  # processing the file.
  #
  # @param [String] filename
  # @param [Boolean] status
  #
  # @return [integer]
  def load_file(filename, status)
    ImportResult::SUCCESS
  end

end # class
end # module
