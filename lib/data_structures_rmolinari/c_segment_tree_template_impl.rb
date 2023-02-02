require 'must_be'

require_relative 'shared'
require_relative 'c_segment_tree_template'

# The template of Segment Tree, which can be used for various interval-related purposes, like efficiently finding the sum (or min or
# max) on a arbitrary subarray of a given array.
#
# There is an excellent description of the data structure at https://cp-algorithms.com/data_structures/segment_tree.html. The
# Wikipedia article (https://en.wikipedia.org/wiki/Segment_tree) appears to describe a different data structure which is sometimes
# called an "interval tree."
#
# For more details (and some close-to-metal analysis of run time, especially for large datasets) see
# https://en.algorithmica.org/hpc/data-structures/segment-trees/. In particular, this shows how to do a bottom-up implementation,
# which is faster, at least for large datasets and cache-relevant compiled code. These issues don't really apply to code written in
# Ruby.
#
# This is a generic implementation, intended to allow easy configuration for concrete instances. See the parameters to the
# initializer and the definitions of concrete realisations like MaxValSegmentTree.
#
# We do O(n) work to build the internal data structure at initialization. Then we answer queries in O(log n) time.
class DataStructuresRMolinari::CSegmentTreeTemplate
  # Construct a concrete instance of a Segment Tree. See details at the links above for the underlying concepts here.
  # @param combine a lambda that takes two values and munges them into a combined value.
  #   - For example, if we are calculating sums over subintervals, combine.call(a, b) = a + b, while if we are doing maxima we will
  #     return max(a, b).
  #   - Things get more complicated when we are calculating, say, the _index_ of the maximal value in a subinterval. Now it is not
  #     enough simply to store that index at each tree node, because to combine the indices from two child nodes we need to know
  #     both the index of the maximal element in each child node's interval, but also the maximal values themselves, so we know
  #     which one "wins" for the parent node. This affects the sort of work we need to do when combining and the value provided by
  #     the +single_cell_array_val+ lambda.
  # @param single_cell_array_val a lambda that takes an index i and returns the value we need to store in the #build
  #     operation for the subinterval i..i.
  #     - This will often simply be the value data[i], but in some cases it will be something else. For example, when we are
  #       calculating the index of the maximal value on each subinterval we need [i, data[i]] here.
  #     - If +update_at+ is called later, this lambda must close over the underlying data in a way that captures the updated value.
  # @param size the size of the underlying data array, used in certain internal arithmetic.
  # @param identity the value to return when we are querying on an empty interval
  #   - for sums, this will be zero; for maxima, this will be -Infinity, etc
  def initialize(combine:, single_cell_array_val:, size:, identity:)
    # having sorted out the keyword arguments, pass them more easily to the C layer.
    c_initialize(combine, single_cell_array_val, size, identity)
  end
end

# A segment tree that for an array A(0...n) answers questions of the form "what is the maximum value in the subinterval A(i..j)?"
# in O(log n) time.
#
# C version
module DataStructuresRMolinari
  class CMaxValSegmentTree
    extend Forwardable

    # Tell the tree that the value at idx has changed
    def_delegator :@structure, :update_at

    # @param data an object that contains values at integer indices based at 0, via +data[i]+.
    #   - This will usually be an Array, but it could also be a hash or a proc.
    def initialize(data)
      @structure = CSegmentTreeTemplate.new(
        combine:               ->(a, b) { [a, b].max },
        single_cell_array_val: ->(i) { data[i] },
        size:                  data.size,
        identity:              -Shared::INFINITY
      )
    end

    # The maximum value in A(i..j).
    #
    # The arguments must be integers in 0...(A.size)
    # @return the largest value in A(i..j) or -Infinity if i > j.
    def max_on(i, j)
      @structure.query_on(i, j)
    end
  end
end
