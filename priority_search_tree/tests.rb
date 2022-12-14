require 'test/unit'
require_relative 'priority_search_tree'

require 'byebug'

class PrioritySearchTreeTest < Test::Unit::TestCase
  INFINITY = Float::INFINITY

  def setup
    puts "In setup..."
    @size = (ENV['test_size'] || 1_000).to_i
    @data = raw_data(@size)
    @tree = PrioritySearchTree.new(@data.clone)
    puts "done"
  end

  def test_construction
    # test_pairs = ([2, 5, 1, 4, 7, 6, 3].zip [3, 5, 2, 1, 6, 7, 4]).map {Pair.new(*_1)}
    # data = test_pairs
    size = (ENV['test_size'] || 10_000).to_i
    data = raw_data(size)
    puts "Building the tree..."
    _tree = PrioritySearchTree.new(data.clone)
  end

  def test_highest_ne
    20.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_highest_ne(x0, y0)
    end
  end

  private def check_a_highest_ne(x0, y0)
    # puts "Calculating highest_ne(#{x0}, #{y0})"
    highest = @data.select{ |pair| pair.x >= x0 && pair.y >= y0 }.max_by(&:y) || Pair.new(INFINITY, -INFINITY)
    calc_highest = @tree.highest_ne(x0, y0)

    assert_equal highest, calc_highest
  end

  private def raw_data(size)
    list = (1..size).to_a
    list.zip(list.shuffle).map { Pair.new(*_1) }.shuffle
  end
end
