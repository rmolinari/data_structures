# A "disjoint set union" that represents a set of elements that belonging to _disjoint_ subsets. Alternatively, this expresses a
# partion of a fixed set.
#
# The data structure provides efficient actions to merge two disjoint subsets, i.e., replace them by their union, and determine if
# two elements are in the same subset.
#
# The elements of the set are 0, 1, ..., n-1, where n is the size of the universe. Client code can map its data to these
# representatives.
#
# See https://en.wikipedia.org/wiki/Disjoint-set_data_structure for a good introduction.
#
# The code uses several ideas from Tarjan and van Leeuwen for efficiency. We use "union by rank" in +unite+ and path-halving in
# +find+. Together, these make the amortized cost of each opperation effectively constant.
#
# - Tarjan, Robert E., van Leeuwen, Jan (1984). _Worst-case analysis of set union algorithms_. Journal of the ACM. 31 (2): 245–281.
#
# @todo
#   - allow caller to expand the size of the universe. This operation is called "make set".
#     - All we need to do is increase the size of @d, set the parent pointers, define the new ranks (zero), and update @size.
class DataStructuresRMolinari::DisjointUnion
  include Shared

  # The number of subsets in the partition.
  attr_reader :subset_count

  # @param size the initial size of the universe. The elements 0, 1, ..., size - 1 start out in disjoint singleton subsets.
  def initialize(size)
    @size = size
    # Initialize to
    @d = (0...size).to_a
    @rank = [0] * size

    @subset_count = size
  end

  # Declare that e and f are equivalent, i.e., in the same subset. If they are already in the same subset this is a no-op.
  #
  # Each argument must be one of 0, 1, ..., size-1.
  def unite(e, f)
    check_value(e)
    check_value(f)
    raise 'Uniting an element with itself is meaningless' if e == f

    e_root = find(e)
    f_root = find(f)
    return if e_root == f_root

    @subset_count -= 1
    link(e_root, f_root)
  end

  # The canonical representative of the subset containing e. Two elements d and e are in the same subset exactly when find(d) ==
  # find(e).
  # @param e must be one of 0, 1, ..., size-1.
  # @return (Integer) one of 0, 1, ..., size-1.
  def find(e)
    check_value(e)

    # We implement find with "halving" to shrink the length of paths to the root. See Tarjan and van Leeuwin p 252.
    x = e
    x = @d[x] = @d[@d[x]] while @d[@d[x]] != @d[x]
    @d[x]
  end

  private def check_value(v)
    raise Shared::DataError, "Value must be given and be in (0..#{@size - 1})" unless v && v.between?(0, @size - 1)
  end

  private def link(e, f)
    # Choose which way around to do the linking using the element "ranks". See Tarjan and van Leeuwen, p 250.
    if @rank[e] > @rank[f]
      @d[f] = e
    elsif @rank[e] == @rank[f]
      @d[f] = e
      @rank[e] += 1
    else
      @d[e] = f
    end
  end
end
