require 'test/unit'
require_relative 'priority_search_tree'

require 'byebug'

class PrioritySearchTreeTest < Test::Unit::TestCase
  def setup
  end


  def test_construction
    # test_pairs = ([2, 5, 1, 4, 7, 6, 3].zip [3, 5, 2, 1, 6, 7, 4]).map {Pair.new(*_1)}
    # data = test_pairs
    size = (ENV['test_size'] || 100_000).to_i
    data = raw_data(size)
    puts "Building the tree..."
    _tree = PrioritySearchTree.new(data.clone)
  end

  private def raw_data(size)
    list = (1..size).to_a
    list.zip(list.shuffle).map { Pair.new(*_1) }.shuffle
  end
end
