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


  def get_importer(options, parse_only: false)
    importer = QFT::ObjImporter.new(parse_only: parse_only)
    importer.send(:process_options, options)
    importer
  end

  def get_test_obj(obj_file)
    basename = File.basename(__FILE__, '.*')
    File.join(__dir__, basename, obj_file)
  end


  # expected = {
  #   width: 1.m,
  #   width: 1.m,
  #   width: 1.m,
  #   materials: 1,
  #   instances: [
  #     {
  #       edges: 12,
  #       faces: 6,
  #     }
  #   ]
  # }
  #
  def assert_imported(expected, model)
    # Root Instance

    instances = model.entities.grep(Sketchup::Group)
    assert_equal(1, instances.size, 'Imported root instances')

    instance = instances.first
    entities = instance.definition.entities

    assert_equal(expected[:width], instance.bounds.width)
    assert_equal(expected[:height], instance.bounds.height)
    assert_equal(expected[:depth], instance.bounds.depth)

    assert_equal(expected[:materials], model.materials.size,
        'Imported materials')

    # Sub-instances.

    instances = entities.grep(Sketchup::Group)
    assert_equal(expected[:instances].size, instances.size,
        'Imported instances')

    instance = instances.first
    entities = instance.definition.entities

    # Sub-entities.

    expected[:instances].each { |inst|

      edges = entities.grep(Sketchup::Edge)
      assert_equal(inst[:edges], edges.size, 'Imported edges')

      faces = entities.grep(Sketchup::Face)
      assert_equal(inst[:faces], faces.size, 'Imported faces')

    }
  end

  def assert_parsed(expected, importer)
    expected.each { |key, exp|
      assert_equal(exp, importer.stats[key], "Parse #{key}")
    }
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

    expected = {
      faces: 6,
      objects: 1,
      errors: 0,
    }
    assert_parsed(expected, importer)
    
    expected = {
      width: 1.m,
      height: 2.m,
      depth: 3.m,
      materials: 1,
      instances: [
        {
          edges: 12,
          faces: 6,
        }
      ]
    }
    assert_imported(expected, model)
  end

end # class
