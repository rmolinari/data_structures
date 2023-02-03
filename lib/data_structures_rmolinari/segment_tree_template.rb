require_relative 'shared'

# A generic implementation of Segment Tree, which can be used for various interval-related purposes, like efficiently finding the
# sum (or min or max) on a arbitrary subarray of a given array.
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
class DataStructuresRMolinari::SegmentTreeTemplate
  include Shared
  include Shared::BinaryTreeArithmetic

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
    @combine = combine
    @single_cell_array_val = single_cell_array_val
    @size = size
    @identity = identity

    @tree = []
    build(root, 0, @size - 1)
  end

  # The desired value (max, sum, etc.) on the subinterval left..right.
  #
  # @param left the left end of the subinterval.
  # @param right the right end (inclusive) of the subinterval.
  #
  # It must be that left..right is contained in 0...size.
  #
  # The type of the return value depends on the concrete instance of the segment tree. We return the _identity_ element provided at
  # construction time if the interval is empty.
  def query_on(left, right)
    raise DataError, "Bad query interval #{left}..#{right} (size = #{@size})" unless (0...@size).cover?(left..right)

    return @identity if left > right # empty interval

    determine_val(root, left, right, 0, @size - 1)
  end

  # Reflect the fact that the underlying array has been updated at the given idx
  #
  # @param idx an index in the underlying data array.
  #
  # Note that we don't need the updated value itself. We get that by calling the lambda +single_cell_array_val+ supplied at
  # construction.
  def update_at(idx)

    update_val_at(idx, root, 0, @size - 1)
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

  private def update_val_at(idx, tree_idx, tree_l, tree_r)
    if tree_l == tree_r
      # We have found the spot!
      raise InternalLogicError, 'tree_l == tree_r, but they do not agree with the idx holding the updated value' unless tree_l == idx

      @tree[tree_idx] = @single_cell_array_val.call(tree_l)
    else
      # Recursively update the appropriate subtree
      mid = midpoint(tree_l, tree_r)
      left = left(tree_idx)
      right = right(tree_idx)
      if mid >= idx
        update_val_at(idx, left, tree_l, mid)
      else
        update_val_at(idx, right, mid + 1, tree_r)
      end
      @tree[tree_idx] = @combine.call(@tree[left], @tree[right])
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
