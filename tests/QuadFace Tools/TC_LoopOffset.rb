#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'testup/testcase'


class TC_LoopOffset < TestUp::TestCase

  QFT = TT::Plugins::QuadFaceTools


  def setup
    start_with_empty_model
  end

  def teardown
    # ...
  end


  def create_test_face
    points = [
      Geom::Point3d.new(0, 0, 0),
      Geom::Point3d.new(9, 0, 0),
      Geom::Point3d.new(9, 9, 0),
      Geom::Point3d.new(0, 9, 0),
    ]
    Sketchup.active_model.active_entities.add_face(points)
  end


  def test_positions_closed_loop
    face = create_test_face
    provider = QFT::EntitiesProvider.new(face.parent.entities)
    offset = QFT::LoopOffset.new(provider)
    offset.loop = face.outer_loop.edges
    offset.origin = face.outer_loop.vertices.first.position
    offset.start_edge = face.outer_loop.edges.first
    offset.start_quad = face
    offset.distance = 3
    assert(offset.ready?, 'loop not ready')
    assert_equal(5, offset.positions.size)
  end

  def test_positions_two_edges
    face = create_test_face
    provider = QFT::EntitiesProvider.new(face.parent.entities)
    offset = QFT::LoopOffset.new(provider)
    offset.loop = face.outer_loop.edges.take(2)
    offset.origin = face.outer_loop.vertices.first.position
    offset.start_edge = face.outer_loop.edges.first
    offset.start_quad = face
    offset.distance = 3
    assert(offset.ready?, 'loop not ready')
    assert_equal(3, offset.positions.size)
  end

  def test_positions_one_edge
    face = create_test_face
    provider = QFT::EntitiesProvider.new(face.parent.entities)
    offset = QFT::LoopOffset.new(provider)
    offset.loop = face.outer_loop.edges.take(1)
    offset.origin = face.outer_loop.vertices.first.position
    offset.start_edge = face.outer_loop.edges.first
    offset.start_quad = face
    offset.distance = 3
    assert(offset.ready?, 'loop not ready')
    assert_equal(2, offset.positions.size)
  end

end # class
