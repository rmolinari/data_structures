require_relative 'shared'

# A Segment Tree, which can be used for various interval-related purposes, like efficiently finding the sum (or min or max) on a
# arbitrary subarray of a given array.
#
# There is an excellent description of the data structure at https://cp-algorithms.com/data_structures/segment_tree.html. The
# Wikipedia article (https://en.wikipedia.org/wiki/Segment_tree) appears to describe a different data structure which is sometimes
# called an "interval tree."
#
# For more details (and some close-to-metal analysis of run time, especially for large datasets) see
# https://en.algorithmica.org/hpc/data-structures/segment-trees/. In particular, this shows how to do a bottom-up
# implementation, which is faster, at least for large datasets and cache-relevant compiled code.
#
# This is a generic implementation.
#
# We do O(n) work to build the internal data structure at initialization. Then we answer queries in O(log n) time.
#
# @todo
#   - provide a data-update operation like update_val_at(idx, val)
#     - this is O(log n)
#     - note that this may need some rework. Consider something like IndexOfMaxVal: @merge needs to know about the underlying data
#       in that case. Hmmm. Maybe the lambda can close over the data in a way that makes it possible to change the data "from the
#       outside". Yes:
#         a = [1,2,3]
#         foo = ->() { a.max }
#         foo.call # 3
#         a = [1,2,4]
#         foo.call # 4
#   - Offer an optional parameter base_case_value_extractor (<-- need better name) to be used in #determine_val in the case that
#     left == tree_l && right == tree_r instead of simply returning @tree[tree_idx]
#     - Use case: https://cp-algorithms.com/data_structures/segment_tree.html#saving-the-entire-subarrays-in-each-vertex, such as
#       finding the least element in a subarray l..r no smaller than a given value x. In this case we store a sorted version the
#       entire subarray at each node and use a binary search on it.
#     - the default value would simply be the identity function.
#     - NOTE that in this case, we have different "combine" functions in #determine_val and #build. In #build we would combine
#       sorted lists into a larger sorted list. In #determine_val we combine results via #min.
#     - Think about the interface before doing this.
class DataStructuresRMolinari::GenericSegmentTree
  include Shared::BinaryTreeArithmetic

  # Construct a concrete instance of a Segment Tree. See details at the links above for the underlying concepts here.
  # @param combine a lambda that takes two values and munges them into a combined value.
  #   - For example, if we are calculating sums over subintervals, combine.call(a, b) = a + b, while if we are doing maxima we will
  #     return max(a, b)
  # @param single_cell_array_val a lambda that takes an index i and returns the value we need to store in the #build
  #     operation for the subinterval i..i. This is often simply be the value data[i], but in some cases - like "index of max val" -
  #     it will be something else.
  # @param size the size of the underlying data array, used in certain internal arithmetic.
  # @param identity is the value to return when we are querying on an empty interval
  #   - for sums, this will be zero; for maxima, this will be -Infinity, etc
  def initialize(combine:, single_cell_array_val:, size:, identity:)
    @combine = combine
    @single_cell_array_val = single_cell_array_val
    @size = size
    @identity = identity

    @tree = []
    build(root, 0, @size - 1)
  end

  # The desired value (max, sum, etc.) on the subinterval left..right.
  # @param left the left end of the subinterval.
  # @param right the right end (inclusive) of the subinterval.
  #
  # The type of the return value depends on the concrete instance of the segment tree.
  def query_on(left, right)
    raise "Bad query interval #{left}..#{right}" if left.negative? || right >= @size

    return @identity if left > right # empty interval

    determine_val(root, left, right, 0, @size - 1)
  end

  private def determine_val(tree_idx, left, right, tree_l, tree_r)
    # Does the current tree node exactly serve up the interval we're interested in?
    return @tree[tree_idx] if left == tree_l && right == tree_r

    # We need to go further down the tree
    mid = midpoint(tree_l, tree_r)
    if mid >= right
      # Our interval is contained by the left child's interval
      determine_val(left(tree_idx),  left, right, tree_l,  mid)
    elsif mid + 1 <= left
      # Our interval is contained by the right child's interval
      determine_val(right(tree_idx), left, right, mid + 1, tree_r)
    else
      # Our interval is split between the two, so we need to combine the results from the children.
      @combine.call(
        determine_val(left(tree_idx),  left,    mid,   tree_l,  mid),
        determine_val(right(tree_idx), mid + 1, right, mid + 1, tree_r)
      )
    end
  end

  # Build the internal data structure.
  #
  # - tree_idx is the index into @tree
  # - tree_l..tree_r is the subinterval of the underlying data that node tree_idx corresponds to
  private def build(tree_idx, tree_l, tree_r)
    if tree_l == tree_r
      @tree[tree_idx] = @single_cell_array_val.call(tree_l) # single-cell interval
    else
      # divide and conquer
      mid = midpoint(tree_l, tree_r)
      left = left(tree_idx)
      right = right(tree_idx)

      build(left, tree_l, mid)
      build(right, mid + 1, tree_r)

      @tree[tree_idx] = @combine.call(@tree[left], @tree[right])
    end
  end

  # Do it in one place so we don't accidently round up here and down there, which would lead to chaos
  private def midpoint(left, right)
    (left + right) / 2
  end
end
