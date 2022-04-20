require 'test/unit'
require_relative 'segment_tree'

require 'byebug'

class IntcodeEngineTest < Test::Unit::TestCase
  def setup
    @size = 10
  end

  def test_all_zeros
    st = fresh_st
    (0...10).each do |v|
      assert_equal 0, st[v]
    end
  end

  def test_set
    validate_sets([[[1, 3], 1]])
    validate_sets([
                    [[2, 7], 1],
                    [[4, 9], 2]
                  ])
  end

  private

  def fresh_st
    SegmentTree.new(@size)
  end

  # range_values is a list of ((l, r), val) pairs, which are to be applied in order to a fresh segment tree. We check that we get
  # the expected values back out again.  Each (l, r) pair is treated as l...r.
  def validate_sets(range_values)
    st = fresh_st
    expected_values = Hash.new(0)

    range_values.each do |rng, val|
      l, r = rng
      (l...r).each { |v| expected_values[v] = val }
      st.set(l, r, val)
    end

    (0...@size).each do |i|
      assert_equal expected_values[i], st[i], "st[#{i}]"
    end
  end
end
