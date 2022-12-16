require 'set'
require 'test/unit'
require_relative 'priority_search_tree'
require_relative 'minmax_priority_search_tree'

require 'byebug'

class PrioritySearchTreeTest < Test::Unit::TestCase
  INFINITY = Float::INFINITY

  def setup
    # puts "In setup..."
    @size = (ENV['test_size'] || 100_000).to_i
    @pairs_by_x = raw_data(@size)
    @tree = PrioritySearchTree.new(@pairs_by_x.shuffle)
    @minmax_tree = MinmaxPrioritySearchTree.new(@pairs_by_x.shuffle)

    @pairs_by_y = @pairs_by_x.sort_by(&:y)

    # puts "done"
  end

  # Construction appears to be fine for now
  def _test_pst_construction
    data = raw_data(@size)
    puts "Building the tree..."
    PrioritySearchTree.new(data.shuffle, verify: true)
  end

  def test_pst_highest_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_highest_ne(x0, y0, @tree)
    end
  end

  def test_pst_leftmost_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_leftmost_ne(x0, y0, @tree)
    end
  end

  def test_minmax_pst_construction
    data = raw_data(@size)
    # puts "Building the minmax PST tree..."
    MinmaxPrioritySearchTree.new(data.shuffle, verify: true)
  end

  # The tree code is buggy here. Let's try to find a small, reproducible error
  def test_minmax_pst_leftmost_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_leftmost_ne(x0, y0, @minmax_tree)
    end
  end

  def test_bad_input_for_minmax_leftmost_ne
    search_for_bad = ENV['search_for_bad']

    if search_for_bad
      loop do
        pairs = raw_data(@size).shuffle
        pst = MinmaxPrioritySearchTree.new(pairs)

        x0 = rand(@size)
        y0 = rand(@size)

        actual_leftmost = pairs.select { |p| p.x >= x0 && p.y >= y0 }.min_by(&:x) || Pair.new(INFINITY, INFINITY)
        calc_leftmost = pst.leftmost_ne(x0, y0)

        if actual_leftmost != calc_leftmost
          puts "x0 = #{x0}"
          puts "y0 = #{y0}"
          pair_data = pairs.map { |p| "[#{p.x},#{p.y}]" }.join(', ')
          puts "data = #{pair_data}"

          assert_equal actual_leftmost, calc_leftmost
        end
      end
    else
      check_one = lambda do |data, x0:, y0:, actual_leftmost:|
        pst = MinmaxPrioritySearchTree.new(data.map { |x, y| Pair.new(x, y) })
        calc_leftmost = pst.leftmost_ne(x0, y0)
        assert_equal actual_leftmost, calc_leftmost
      end

      # Some inputs on which the code was found to be buggy
      check_one.call(
        [[4,10], [2,1], [8,2], [3,5], [7,7], [9,9], [10,8], [1,4], [5,3], [6,6]],
        x0: 5, y0: 6,
        actual_leftmost: Pair.new(6, 6)
      )

      $do_it = true
      check_one.call(
        [
          [20,32], [1,1], [17,2], [2,31], [15,26], [24,30], [30,29], [5,4], [9,10], [11,18], [16,3], [19,8], [22,11], [28,5],
          [31,7], [3,21], [6,9], [7,22], [8,28], [10,25], [12,23], [13,19], [14,6], [18,27], [21,13], [23,14], [25,24], [26,12],
          [27,17], [29,20], [32,16], [4,15]
        ],
        x0: 4, y0: 11,
        actual_leftmost: Pair.new(4, 15)
      )
    end
  end

  ########################################
  # Helpers

  private def check_a_highest_ne(x0, y0, pst)
    # puts "Calculating highest_ne(#{x0}, #{y0})"
    highest = ne_quadrant(x0, y0).max_by(&:y) || Pair.new(INFINITY, -INFINITY)
    calc_highest = pst.highest_ne(x0, y0)

    assert_equal highest, calc_highest
  end

  private def check_a_leftmost_ne(x0, y0, pst)
    # puts "Calculating leftmost_ne(#{x0}, #{y0})"
    leftmost = ne_quadrant(x0, y0).min_by(&:x) || Pair.new(INFINITY, INFINITY)
    calc_leftmost = pst.leftmost_ne(x0, y0)

    assert_equal leftmost, calc_leftmost
  end

  private def raw_data(size)
    list = (1..size).to_a
    list.zip(list.shuffle).map { Pair.new(*_1) }
  end

  # Points (x,y) in @data with x >= x0
  private def rightward_points(x0)
    first_idx = @pairs_by_x.bsearch_index { |v| v.x >= x0 }
    @pairs_by_x[first_idx..]
  end

  private def upward_points(y0)
    first_idx = @pairs_by_y.bsearch_index { |v| v.y >= y0 }
    @pairs_by_y[first_idx..]
  end

  private def ne_quadrant(x0, y0)
    if x0 > y0
      rightward_points(x0).select { |pair| pair.y >= y0 }
    else
      upward_points(y0).select { |pair| pair.x >= x0 }
    end
  end
end
