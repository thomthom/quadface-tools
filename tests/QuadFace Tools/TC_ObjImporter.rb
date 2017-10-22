#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


require 'testup/testcase'


class TC_ObjImporter < TestUp::TestCase

  QFT = TT::Plugins::QuadFaceTools


  def setup
    start_with_empty_model
  end

  def teardown
    # ...
  end


  def get_importer(options)
    importer = QFT::ObjImporter.new
    importer.send(:process_options, options)
    importer
  end

  def get_test_obj(obj_file)
    basename = File.basename(__FILE__, '.*')
    File.join(__dir__, basename, obj_file)
  end


  def test_import_sketchup_cube_obj
    model = Sketchup.active_model
    obj_file = get_test_obj('SketchUp-Cube.obj')

    options = {
      units: QFT::ObjImporter::UNIT_MILLIMETERS,
      swap_yz: false,
    }
    importer = get_importer(options)
    importer.load_file(obj_file, false)    

    # Root Instance

    instances = model.entities.grep(Sketchup::Group)
    assert_equal(1, instances.size, 'Imported root instances')

    instance = instances.first
    entities = instance.definition.entities

    assert_equal(1.m, instance.bounds.width)
    assert_equal(2.m, instance.bounds.height)
    assert_equal(3.m, instance.bounds.depth)

    # Sub-instances.

    instances = entities.grep(Sketchup::Group)
    assert_equal(1, instances.size, 'Imported instances')

    instance = instances.first
    entities = instance.definition.entities

    # Sub-entities.

    edges = entities.grep(Sketchup::Edge)
    assert_equal(12, edges.size, 'Imported edges')

    faces = entities.grep(Sketchup::Face)
    assert_equal(6, faces.size, 'Imported faces')

    assert_equal(1, model.materials.size, 'Imported materials')
  end

end # class
