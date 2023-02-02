require 'test/unit'
require 'byebug'

require 'data_structures_rmolinari'

MaxValSegmentTree = DataStructuresRMolinari::MaxValSegmentTree
CMaxValSegmentTree = DataStructuresRMolinari::CMaxValSegmentTree

IndexOfMaxValSegmentTree = DataStructuresRMolinari::IndexOfMaxValSegmentTree
CIndexOfMaxValSegmentTree = DataStructuresRMolinari::CIndexOfMaxValSegmentTree

class SegmentTreeTest < Test::Unit::TestCase
  DATA = [
      -1, 7, 1, -4, 3, 0, -4, 1, -8, 9, -5, -10, 4, -9, 3, 8, 3, 6, 7, 1, -4, 8, -9, -6, 10, -10, 7, 9, -6, -10, 5, -4, -1, -2, 4,
      3, -10, -8, 9, 2
    ]

  def test_max_val_segment_tree
    test_seg_tree_basic(MaxValSegmentTree, :max_on, DATA) { |i, j| DATA[i..j].max }
  end

  def test_max_val_segment_tree_updates
    mutable_data = DATA.clone
    test_seg_tree_with_updates(MaxValSegmentTree, :max_on, mutable_data) { |i, j| mutable_data[i..j].max }
  end

  def test_index_of_max_val_segment_tree
    test_seg_tree_basic(IndexOfMaxValSegmentTree, :index_of_max_val_on, DATA) { |i, j| (i..j).max_by { DATA[_1] } }
  end

  def test_index_of_max_val_segment_tree_updates
    mutable_data = DATA.clone
    test_seg_tree_with_updates(IndexOfMaxValSegmentTree, :index_of_max_val_on, mutable_data) { |i, j| (i..j).max_by { mutable_data[_1] } }
  end

  ########################################
  # C implementation

  # Can we call the initializer without problems?
  def test_c_max_val_segment_tree_init
    _c_tree = CMaxValSegmentTree.new(DATA)
  end

  def test_c_max_val_segment_tree
    test_seg_tree_basic(CMaxValSegmentTree, :max_on, DATA) { |i, j| DATA[i..j].max }
  end

  def test_c_index_of_max_val_segment_tree
    test_seg_tree_basic(CIndexOfMaxValSegmentTree, :index_of_max_val_on, DATA) { |i, j| (i..j).max_by { DATA[_1] } }
  end

  ########################################
  # Helpers

  private def test_seg_tree_basic(klass, method, data, &block)
    seg_tree = klass.new(data)
    check_all_intervals(seg_tree, method, data.size) { |i, j| block.call(i, j) }
  end

  private def test_seg_tree_with_updates(klass, method, mutable_data, &block)
    seg_tree = klass.new(mutable_data)
    (0...(mutable_data.size)).each do |idx|
      mutable_data[idx] += rand(-5..5)
      seg_tree.update_at(idx)
      check_all_intervals(seg_tree, method, mutable_data.size) { |i, j| block.call(i, j) }
    end
  end

  private def check_all_intervals(segment_tree, method, data_size)
    (0...data_size).each do |i|
      (i...data_size).each do |j|
        expected_value = yield(i, j)
        actual_value = segment_tree.send(method, i, j)
        assert_equal expected_value, actual_value
      end
    end
  end
end
