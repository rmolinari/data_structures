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
  #
  # TODO:
  # - allow min val too
  #   - add a flag to the initializer
  #   - call it ExtremalValSegment tree or something similar
  class MaxValSegmentTree
    extend Forwardable

    def_delegator :@structure, :query_on, :max_on

    def initialize(data)
      @structure = GenericSegmentTree.new(
        combine:               ->(a, b) { [a, b].max },
        single_cell_array_val: ->(i) { data[i] },
        size:                  data.size,
        identity:              -Float::INFINITY
      )
    end
  end
end
