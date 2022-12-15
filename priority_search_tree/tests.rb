require 'set'
require 'test/unit'
require_relative 'priority_search_tree'

require 'byebug'

class PrioritySearchTreeTest < Test::Unit::TestCase
  INFINITY = Float::INFINITY

  def setup
    # puts "In setup..."
    @size = (ENV['test_size'] || 100_000).to_i
    @pairs_by_x = raw_data(@size)
    @tree = PrioritySearchTree.new(@pairs_by_x.shuffle)

    @pairs_by_y = @pairs_by_x.sort_by(&:y)

    # puts "done"
  end

  # Construction appears to be fine for now
  def _test_construction
    data = raw_data(@size)
    puts "Building the tree..."
    PrioritySearchTree.new(data.shuffle, verify: true)
  end

  def test_highest_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_highest_ne(x0, y0)
    end
  end

  def test_leftmost_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_leftmost_ne(x0, y0)
    end
  end

  private def check_a_highest_ne(x0, y0)
    # puts "Calculating highest_ne(#{x0}, #{y0})"
    highest = ne_quadrant(x0, y0).max_by(&:y) || Pair.new(INFINITY, -INFINITY)
    calc_highest = @tree.highest_ne(x0, y0)

    assert_equal highest, calc_highest
  end

  private def check_a_leftmost_ne(x0, y0)
    # puts "Calculating leftmost_ne(#{x0}, #{y0})"
    leftmost = ne_quadrant(x0, y0).min_by(&:x) || Pair.new(INFINITY, INFINITY)
    calc_leftmost = @tree.leftmost_ne(x0, y0)

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
