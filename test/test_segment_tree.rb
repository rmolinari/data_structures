require 'test/unit'
require 'byebug'
require 'must_be'

require 'data_structures_rmolinari'

SegmentTree = DataStructuresRMolinari::SegmentTree

class SegmentTreeTest < Test::Unit::TestCase
  DATA = [
      -1, 7, 1, -4, 3, 0, -4, 1, -8, 9, -5, -10, 4, -9, 3, 8, 3, 6, 7, 1, -4, 8, -9, -6, 10, -10, 7, 9, -6, -10, 5, -4, -1, -2, 4,
      3, -10, -8, 9, 2
    ]

  def test_max_val_segment_tree
    seg_tree = make_one(:max, :ruby, DATA)
    test_seg_tree_basic(seg_tree, :max_on, DATA.size) { |i, j| DATA[i..j].max }
  end

  def test_max_val_segment_tree_updates
    mutable_data = DATA.clone
    seg_tree = make_one(:max, :ruby, mutable_data)
    test_seg_tree_with_updates(seg_tree, :max_on, mutable_data) { |i, j| mutable_data[i..j].max }
  end

  def test_index_of_max_val_segment_tree
    seg_tree = make_one(:index_of_max, :ruby, DATA)
    test_seg_tree_basic(seg_tree, :index_of_max_val_on, DATA.size) { |i, j| (i..j).max_by { DATA[_1] } }
  end

  def test_index_of_max_val_segment_tree_updates
    mutable_data = DATA.clone
    seg_tree = make_one(:index_of_max, :ruby, mutable_data)
    test_seg_tree_with_updates(seg_tree, :index_of_max_val_on, mutable_data) { |i, j| (i..j).max_by { mutable_data[_1] } }
  end

  ########################################
  # C implementation

  def test_max_val_segment_tree_with_c
    seg_tree = make_one(:max, :c, DATA)
    test_seg_tree_basic(seg_tree, :max_on, DATA.size) { |i, j| DATA[i..j].max }
  end

  def test_max_val_segment_tree_updates_with_c
    mutable_data = DATA.clone
    seg_tree = make_one(:max, :c, mutable_data)
    test_seg_tree_with_updates(seg_tree, :max_on, mutable_data) { |i, j| mutable_data[i..j].max }
  end

  def test_index_of_max_val_segment_tree_with_c
    seg_tree = make_one(:index_of_max, :c, DATA)
    test_seg_tree_basic(seg_tree, :index_of_max_val_on, DATA.size) { |i, j| (i..j).max_by { DATA[_1] } }
  end

  def test_index_of_max_val_segment_tree_updates_with_c
    mutable_data = DATA.clone
    seg_tree = make_one(:index_of_max, :c, mutable_data)
    test_seg_tree_with_updates(seg_tree, :index_of_max_val_on, mutable_data) { |i, j| (i..j).max_by { mutable_data[_1] } }
  end

  ########################################
  # Helpers

  private def test_seg_tree_basic(seg_tree, method, data_size, &block)
    check_all_intervals(seg_tree, method, data_size) { |i, j| block.call(i, j) }
  end

  private def test_seg_tree_with_updates(seg_tree, method, mutable_data, &block)
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

  private def make_one(op, lang, data)
    SegmentTree.construct(data, op, lang)
  end
end
