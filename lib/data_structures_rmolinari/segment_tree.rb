require_relative 'shared'

# A namespace to hold the various bits and bobs related to the SegmentTree implementation
module DataStructuresRMolinari::SegmentTree
end

require_relative 'segment_tree_template'   # Ruby implementation of the generic API
require_relative 'c_segment_tree_template' # native extension: loads CSegmentTreeTemplate class
require_relative 'c_segment_tree_template_impl' # Ruby constructor / Fixnum fast-path wiring

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
# backed either by the pure Ruby SegmentTreeTemplate or its C-based sibling CSegmentTreeTemplate
module DataStructuresRMolinari
  module SegmentTree
    # A convenience method to construct a Segment Tree that, for a given indexed backing store A(0...size), answers questions of the
    # kind given by operation, using the template written in lang
    #
    # - @param data: the indexed backing store A.
    #   - Must respond to #[] with an integer index in 0...size and to #size with a non-negative Integer length.
    #   - Typically an Array or Hash with keys 0...; a raw Proc does not implement #size, so use
    #     SegmentTree.indexed_proc(size) { |i| ... } for proc-like access
    # - @param operation: a supported "style" of Segment Tree
    #   - must be one of these (but you can write your own concrete version)
    #     - :max: implementing max_on(i, j), returning the maximum value in A(i..j)
    #     - :index_of_max: implementing index_of_max_val_on(i, j), returning an index corresponding to the maximum value in
    #       A(i..j).
    #     - :sum: implementing sum_on(i, j)
    #     - :min: implementing min_on(i, j)
    #     - :product: implementing product_on(i, j)
    # - @param lang: the language in which the underlying "template" is written
    #   - :c or :ruby
    #   - the C version will run faster but is harder to debug
    #     - if the operation is :max, :sum, or :product and the data is an Array of Fixnums, then the C version will use a "fast
    #       path" that stores the data in a native C array and thus avoids most Ruby callbacks.
    module_function def construct(data, operation, lang)
      operation.must_be_in [:max, :index_of_max, :sum, :min, :product]
      lang.must_be_in [:ruby, :c]

      klass = case operation
              when :max then MaxValSegmentTree
              when :index_of_max then IndexOfMaxValSegmentTree
              when :sum then SumSegmentTree
              when :min then MinValSegmentTree
              when :product then ProductSegmentTree
              else raise ArgumentError, "Unknown operation #{operation}"
              end
      template = lang == :ruby ? SegmentTreeTemplate : CSegmentTreeTemplate

      klass.new(template, data)
    end

    # True if data is an Array whose elements are all Ruby Fixnums (immediate integers), suitable for the C extension's fixnum fast
    # path when combined with :max, :sum, or :product.
    module_function def fixnum_fast_path_data?(data)
      data.is_a?(Array) && CSegmentTreeTemplate.all_fixnums_for_fast_path?(data)
    end

    # Raises unless data supports segment-tree indexing (#[] with integer keys in 0...size, #size as non-negative Integer).
    module_function def must_be_indexed_backing!(data)
      unless data.respond_to?(:[]) && data.respond_to?(:size)
        raise ArgumentError, 'backing store must respond to #[] (index) and #size (length)'
      end

      sz = data.size
      raise ArgumentError, '#size must return a non-negative Integer' unless sz.is_a?(Integer) && !sz.negative?
    end

    # A small object that responds to #[] passing the index to a block, and responds to #size with the given argument.
    #
    # Uuse when the backing store is not an Array or Hash (a plain Proc does not implement #size).
    module_function def indexed_proc(size, &block)
      raise ArgumentError, 'block required' unless block
      raise ArgumentError, 'size must be a non-negative Integer' unless size.is_a?(Integer) && !size.negative?

      Object.new.tap do |o|
        o.define_singleton_method(:size) { size }
        o.define_singleton_method(:[]) { |i| block.call(i) }
      end
    end

    # Internal: FoldIndexedDataTemplate.build constructs max/sum/product segment-tree templates; including this module adds
    # private template_query_on (max_on, sum_on, product_on are aliased to it on concrete classes).
    module FoldIndexedDataTemplate
      class << self
        def build(template_klass, data, fixnum_op:, combine:, identity:)
          SegmentTree.must_be_indexed_backing!(data)
          if template_klass == CSegmentTreeTemplate && data.is_a?(Array) && SegmentTree.fixnum_fast_path_data?(data)
            # fast path
            template_klass.new(fixnum_op:, data:, identity:)
          else
            size = data.size
            template_klass.new(
              combine:, identity:, size:,
              single_cell_array_val: ->(i) { data[i] }  # close over the data
            )
          end
        end
      end

      private

      def template_query_on(i, j)
        @structure.query_on(i, j)
      end
    end
    private_constant :FoldIndexedDataTemplate

    # A segment tree that for an array A(0...n) answers questions of the form "what is the maximum value in the subinterval A(i..j)?"
    # in O(log n) time.
    class MaxValSegmentTree
      extend Forwardable
      include FoldIndexedDataTemplate

      # Tell the tree that the value at idx has changed
      def_delegator :@structure, :update_at

      # @param data (see DataStructuresRMolinari::SegmentTree.construct)
      def initialize(template_klass, data)
        @structure = FoldIndexedDataTemplate.build(template_klass, data,
                                                   fixnum_op: :max,
                                                   combine:   ->(a, b) { [a, b].max },
                                                   identity:  -Shared::INFINITY)
      end

      # The maximum value in A(i..j).
      #
      # The arguments must be integers in 0...(A.size)
      # @return the largest value in A(i..j) or -Infinity if i > j.
      alias_method :max_on, :template_query_on
      public :max_on
    end

    class SumSegmentTree
      extend Forwardable
      include FoldIndexedDataTemplate

      # Tell the tree that the value at idx has changed
      def_delegator :@structure, :update_at

      # @param (see MaxValSegmentTree#initialize)
      def initialize(template_klass, data)
        @structure = FoldIndexedDataTemplate.build(template_klass, data,
                                                   fixnum_op: :sum,
                                                   combine:   ->(a, b) { a + b },
                                                   identity:  0)
      end

      # The sum of the values in A(i..j)
      #
      # The arguments must be integers in 0...(A.size)
      # @return the sum of the values in A(i..j) or 0 if i > j.
      alias_method :sum_on, :template_query_on
      public :sum_on
    end

    # A segment tree that answers "what is the product of the values in A(i..j)?" in O(log n) time.
    #
    # The C Fixnum fast path stores aggregates in a +long long+ and raises RangeError on overflow. The Ruby template uses Ruby
    # integer arithmetic (unbounded).
    class ProductSegmentTree
      extend Forwardable
      include FoldIndexedDataTemplate

      def_delegator :@structure, :update_at

      def initialize(template_klass, data)
        @structure = FoldIndexedDataTemplate.build(template_klass, data,
                                                   fixnum_op: :product,
                                                   combine:   ->(a, b) { a * b },
                                                   identity:  1)
      end

      # The product of the values in A(i..j)
      #
      # The arguments must be integers in 0...(A.size)
      # @return the product of the values in A(i..j) or 1 if i > j.
      alias_method :product_on, :template_query_on
      public :product_on
    end

    # A segment tree that for an array A(0...n) answers questions of the form "what is the index of the maximal value in the
    # subinterval A(i..j)?" in O(log n) time.
    class IndexOfMaxValSegmentTree
      extend Forwardable

      # Tell the tree that the value at idx has changed
      def_delegator :@structure, :update_at

      # @param (see MaxValSegmentTree#initialize)
      def initialize(template_klass, data)
        SegmentTree.must_be_indexed_backing!(data)

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
        @structure.query_on(i, j)&.first # discard the value part of the pair, which is just bookkeeping
      end
    end

    # Read-through view: self[i] returns -store[i]. Used by MinValSegmentTree when no materialized negated Array is needed.
    class NegatedIndexedView
      def initialize(store)
        @store = store
      end

      def size
        @store.size
      end

      def [](i)
        -@store[i]
      end
    end
    private_constant :NegatedIndexedView

    # A segment tree that answers "what is the minimum value in A(i..j)?" in O(log n) time.

    # The functionality is equivalent to the _max_ over the negated values.  There is a bit more bookkeeping on top to support data
    # mutations.
    class MinValSegmentTree
      def initialize(template_klass, data)
        SegmentTree.must_be_indexed_backing!(data)
        @data = data

        # C fixnum max path requires a real +Array+ of negated Fixnums; otherwise a read-through negated view is enough.
        @negated_materialized =
          if data.is_a?(Array) && template_klass == CSegmentTreeTemplate && SegmentTree.fixnum_fast_path_data?(data)
            data.map { |x| -x }
          end

        negated_for_max = @negated_materialized || NegatedIndexedView.new(data)
        @max_segment_tree = MaxValSegmentTree.new(template_klass, negated_for_max)
      end

      def min_on(i, j)
        -@max_segment_tree.max_on(i, j)
      end

      def update_at(idx)
        @negated_materialized[idx] = -@data[idx] if @negated_materialized
        @max_segment_tree.update_at(idx)
      end
    end
  end
end
