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
  # Concrete example of Segment Tree

  # Takes an array A[0...n] and tells us what the maximum value is on a subinterval i..j in O(log n) time.
  class MaxValSegmentTree
    extend Forwardable

    def_delegator :@structure, :query_on, :max_on
    def_delegator :@structure, :update_at

    # @param data an object that contains values at integer indices based at 0, via +data[i]+.
    #   The usual use-case will be an Array, but it could also be a hash or a proc of some sort.
    def initialize(data)
      @structure = GenericSegmentTree.new(
        combine:               ->(a, b) { [a, b].max },
        single_cell_array_val: ->(i) { data[i] },
        size:                  data.size,
        identity:              -Float::INFINITY
      )
    end
  end

  # A segment tree that for an array A[0..n] efficiently answers questions of the form "what is the index of the maximal value in
  # A[i..j]?".
  class IndexOfMaxValSegmentTree
    extend Forwardable

    def_delegator :@structure, :update_at

    def self.combine_pairs(pair1, pair2)
      idx1, val1 = pair1
      idx2, val2 = pair2
      if val1 >= val2
        [idx1, val1]
      else
        [idx2, val2]
      end
    end

    # @param (see MaxValSegmentTree#initialize)
    def initialize(data)
      @structure = GenericSegmentTree.new(
        combine:               ->(p1, p2) { self.class.combine_pairs(p1, p2) },
        single_cell_array_val: ->(i) { [i, data[i]] },
        size:                  data.size,
        identity:              nil
      )
    end

    # The index of the maximum value among data[i..j].
    #
    # The arguments must be integers in 0...(data.size).
    # @return the index of the largest value in data[i..j]
    def index_of_max_val_on(i, j)
      @structure.query_on(i, j).first # discard the value part of the pair
    end
  end
end
