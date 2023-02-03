require_relative 'shared'

module DataStructuresRMolinari
  # A namespace to hold the various bits and bobs related to the SegmentTree implementation
  module SegmentTree
  end
end

require_relative 'segment_tree_template'
require_relative 'c_segment_tree_template_impl'

# Segment Tree: various concrete implementations
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
# Here we provide several concrete segment tree implementations built on top of the template (generic) versions. Each instance is
#backed either by the pure Ruby SegmentTreeTemplate or its C-based sibling CSegmentTreeTemplate
#
module DataStructuresRMolinari
  module SegmentTree
    # A convenience method to construct a Segment Tree that, for a given array A(0...size), answers questions of the kind given by
    # operation, using the template written in lang
    #
    # - @param data: the array A.
    #   - It must respond to +#size# and to +#[]+ with non-negative integer arguments.
    # - @param operation: a supported "style" of Segment Tree
    #   - for now, must be one of these (but you can write your own concrete version)
    #     - +:max+: implementing +max_on(i, j)+, returning the maximum value in A(i..j)
    #     - +:index_of_max+: implementing +index_of_max_val_on(i, j)+, returning an index corresopnding to the maximum value in
    #       A(i..j).
    # - @param lang: the language in which the underlying "template" is written
    #   - +:c+ or +:ruby+
    #   - the C version will run faster but may be buggier
    module_function def construct(data, operation, lang)
      operation.must_be_in [:max, :index_of_max]
      lang.must_be_in [:ruby, :c]

      klass = operation == :max ? MaxValSegmentTree : IndexOfMaxValSegmentTree
      template = lang == :ruby ? SegmentTreeTemplate : CSegmentTreeTemplate

      klass.new(template, data)
    end

    # A segment tree that for an array A(0...n) answers questions of the form "what is the maximum value in the subinterval A(i..j)?"
    # in O(log n) time.
    class MaxValSegmentTree
      extend Forwardable

      # Tell the tree that the value at idx has changed
      def_delegator :@structure, :update_at

      # @param template_klass the "template" class that provides the generic implementation of the Segment Tree functionality.
      # @param data an object that contains values at integer indices based at 0, via +data[i]+.
      #   - This will usually be an Array, but it could also be a hash or a proc.
      def initialize(template_klass, data)
        data.must_be_a Enumerable

        @structure = template_klass.new(
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

    # A segment tree that for an array A(0...n) answers questions of the form "what is the index of the maximal value in the
    # subinterval A(i..j)?" in O(log n) time.
    class IndexOfMaxValSegmentTree
      extend Forwardable

      # Tell the tree that the value at idx has changed
      def_delegator :@structure, :update_at

      # @param (see MaxValSegmentTree#initialize)
      def initialize(template_klass, data)
        data.must_be_a Enumerable

        @structure = template_klass.new(
          combine:               ->(p1, p2) { p1[1] >= p2[1] ? p1 : p2 },
          single_cell_array_val: ->(i) { [i, data[i]] },
          size:                  data.size,
          identity:              nil
        )
      end

      # The index of the maximum value in A(i..j)
      #
      # The arguments must be integers in 0...(A.size)
      # @return (Integer, nil) the index of the largest value in A(i..j) or +nil+ if i > j.
      #   - If there is more than one entry with that value, return one the indices. There is no guarantee as to which one.
      #   - Return +nil+ if i > j
      def index_of_max_val_on(i, j)
        @structure.query_on(i, j)&.first # discard the value part of the pair, which is a bookkeeping
      end
    end
  end
end
