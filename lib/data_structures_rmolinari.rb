require_relative 'data_structures_rmolinari/shared'

module DataStructuresRMolinari
  Pair = Shared::Pair
end

# These define classes inside module DataStructuresRMolinari
require_relative 'data_structures_rmolinari/disjoint_union'
require_relative 'data_structures_rmolinari/generic_segment_tree'
require_relative 'data_structures_rmolinari/heap'
require_relative 'data_structures_rmolinari/max_priority_search_tree'
require_relative 'data_structures_rmolinari/minmax_priority_search_tree'

module DataStructuresRMolinari
  ########################################
  # Concrete instances of Segment Tree
  #
  # @todo consider moving these into generic_segment_tree.rb

  # Takes an array A(0...n) and tells us what the maximum value is on a subinterval A(i..j) in O(log n) time.
  class MaxValSegmentTree
    extend Forwardable

    # Tell the tree that the value at idx has changed
    def_delegator :@structure, :update_at

    # @param data an object that contains values at integer indices based at 0, via +data[i]+.
    #   - The usual use case will be an Array, but it could also be a hash or a proc of some sort.
    def initialize(data)
      @structure = GenericSegmentTree.new(
        combine:               ->(a, b) { [a, b].max },
        single_cell_array_val: ->(i) { data[i] },
        size:                  data.size,
        identity:              -Float::INFINITY
      )
    end

    # The maximum value in A(i..j)
    #
    # The arguments must be integers in 0...(A.size)
    # @return the largest value in A(i..j).
    #   - Return +nil+ if i > j
    def max_on(i, j)
      @structure.query_on(i, j)
    end
  end

  # A segment tree that for an array A(0...n) efficiently answers questions of the form "what is the index of the maximal value in
  # a subinterval A(i..j) in O(log n) time.
  class IndexOfMaxValSegmentTree
    extend Forwardable

    # Tell the tree that the value at idx has changed
    def_delegator :@structure, :update_at

    # @param (see MaxValSegmentTree#initialize)
    def initialize(data)
      @structure = GenericSegmentTree.new(
        combine:               ->(p1, p2) { p1[1] >= p2[1] ? p1 : p2 },
        single_cell_array_val: ->(i) { [i, data[i]] },
        size:                  data.size,
        identity:              nil
      )
    end

    # The index of the maximum value in A(i..j)
    #
    # The arguments must be integers in 0...(A.size)
    # @return (Integer, nil) the index of the largest value in A(i..j).
    #   - If there is more than one entry with that value, return one the indices. There is no guarantee as to which one.
    #   - Return +nil+ if i > j
    def index_of_max_val_on(i, j)
      @structure.query_on(i, j)&.first # discard the value part of the pair
    end
  end
end
