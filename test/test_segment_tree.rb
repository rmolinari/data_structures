require 'test/unit'
require 'byebug'

require 'data_structures_rmolinari'

MaxValSegmentTree = DataStructuresRMolinari::MaxValSegmentTree

class SegmentTreeTest < Test::Unit::TestCase
  def test_max_val_segment_tree
    seg_tree = MaxValSegmentTree.new(data)

    # Do it! Gotta try them all!
    (0...size).each do |i|
      (i...size).each do |j|
        assert_equal seg_tree.max_on(i, j), data[i..j].max
      end
    end
  end

  def test_max_val_segment_tree_updates
    mutable_data = data.clone
    seg_tree = MaxValSegmentTree.new(mutable_data)
    (0...(data.size)).each do |idx|
      mutable_data[idx] += rand(-5..5)
      seg_tree.update_at(idx)
      check_all_intervals_for_max(seg_tree, mutable_data)
    end
  end

  private def data
    @data ||= [
      -1, 7, 1, -4, 3, 0, -4, 1, -8, 9, -5, -10, 4, -9, 3, 8, 3, 6, 7, 1, -4, 8, -9, -6, 10, -10, 7, 9, -6, -10, 5, -4, -1, -2, 4,
      3, -10, -8, 9, 2
    ]
  end

  private def check_all_intervals_for_max(segment_tree, data)
    size = data.size

    (0...size).each do |i|
      (i...size).each do |j|
        assert_equal segment_tree.max_on(i, j), data[i..j].max
      end
    end
  end
end
