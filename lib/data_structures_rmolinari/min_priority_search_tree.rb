require 'must_be'
require 'set'
require_relative 'shared'

# A priority search tree (PST) stores a set, P, of two-dimensional points (x,y) in a way that allows efficient answers to certain
# questions about P.
#
# This is a _Mininmal_ Priority Search Tree (MinPST), a slight variant of the MaxPST. Where a MaxPST can answer queries about
# regions infinite in the positive y direction, a MinPST can handle regions infinite in the negative y direction. (A MinmaxPST can
# handle both kinds of region but has not been implemented.)
#
# The PST data structure was introduced in 1985 by Edward McCreight. Later, De, Maheshwari, Nandy, and Smid showed how to construct
# a PST in-place (using only O(1) extra memory), at the expense of some slightly more complicated code for the various supported
# operations. It is their approach that we have implemented. See the class +MaxPrioritySearchTree+ for more details.
#
# Here we implement the MinPST by adding a thin layer of code over a MaxPST and reflecting all points through the x-axis.
#
# This means a few things.
# - The bookkeeping means that performance will be slightly slower than for the MaxPST due to the bookkeeping. It is unlikely to be
#   noticable in practice.
# - MaxPST builds the tree structure in place, modifying the data array passed it. Indeed, this is the point of the approach of De
#   et al. But we don't do that, as we create a separate array of Points.
# - Whereas the implementation of MaxPST means that client code gets the same (x, y) objects back in results as it passed into the
#   contructor, that's not the case here.
#   - we map each point in the input - which is an object responding to +#x+ and +#y+ - to an instance of +Point+, and will return
#    (different) instances of +Point+ in response to queries.
#   - client code is unlikely to care, but be aware of this, just in case.
#
# Given a set of n points, we can answer the following questions quickly:
#
# - +smallest_x_in_se+: for x0 and y0, what is the "leftmost" point (x, y) in P satisfying x >= x0 and y <= y0?
# - +largest_x_in_sw+: for x0 and y0, what is the "rightmost" point (x, y) in P satisfying x <= x0 and y <= y0?
# - +smallest_y_in_se+: for x0 and y0, what is the "lowest" point (x, y) in P satisfying x >= x0 and y <= y0?
# - +smallest_y_in_nw+: for x0 and y0, what is the lowest point (x, y) in P satisfying x <= x0 and y <= y0?
# - +smallest_y_in_3_sided+: for x0, x1, and y0, what is the lowest point (x, y) in P satisfying x >= x0, x <= x1 and y <= y0?
# - +enumerate_3_sided+: for x0, x1, and y0, enumerate all points in P satisfying x >= x0, x <= x1 and y <= y0.
#
# (Here, "leftmost/rightmost" means "minimal/maximal x", and "lowest" means "minimal y".)
#
# The first 5 operations take O(log n) time and O(1) extra space.
#
# The final operation (enumerate) takes O(m + log n) time and O(1) extra space, where m is the number of points that are enumerated.
#
# As with the MaxPST the MinPST can be contructed to be "dynamic" and provide a +delete_top!+ operation running in O(log n) time.
#
# In the current implementation no two points can share an x-value. This (rather severe) restriction can be relaxed with some more
# complicated code, but it hasn't been written yet. See issue #9.
#
# References:
# * E.M. McCreight, _Priority search trees_, SIAM J. Comput., 14(2):257-276, 1985.
# * M. De, A. Maheshwari, S. C. Nandy, M. Smid, _An In-Place Priority Search Tree_, 23rd Canadian Conference on Computational
#   Geometry, 2011
class DataStructuresRMolinari::MinPrioritySearchTree
  include Shared
  include BinaryTreeArithmetic

  # Construct a MinPST from the collection of points in +data+.
  #
  # @param data [Array] the set P of points as an array. The internal data structure is constructed in-place inside this array
  #     without cloning it. Indeed, each element of data is replaced by a different object.
  #   - Each element of the array must respond to +#x+ and +#y+.
  #   - The +x+ values must be distinct. We raise a +Shared::DataError+ if this isn't the case.
  #     - This is a restriction that simplifies some of the algorithm code. It can be removed as the cost of some extra work. Issue
  #       #9.
  #
  # @param verify [Boolean] when truthy, check that the properties of a PST are satisified after construction, raising an exception
  #        if not.
  def initialize(data, dynamic: false, verify: false)
    (0...(data.size)).each do |i|
      data[i] = flip data[i]
    end
    @max_pst = DataStructuresRMolinari::MaxPrioritySearchTree.new(data, dynamic:, verify:)
  end

  ########################################
  # "Lowest" points in SE and SW quadrants

  # Return the "lowest" point in P to the "southeast" of (x0, y0).
  #
  # Let Q = [x0, infty) X (infty, y0] be the southeast quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (infty, infty) if Q \intersect P is empty and
  # - the lowest (min-y) point in Q \intersect P otherwise, breaking ties by preferring smaller values of x
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def smallest_y_in_se(x0, y0, open: false)
    flip @max_pst.largest_y_in_ne(x0, -y0, open:)
  end

  # Return the "lowest" point in P to the "southwest" of (x0, y0).
  #
  # Let Q = (-infty, x0] X (-infty, y0] be the southwest quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (-infty, infty) if Q \intersect P is empty and
  # - the lowest (min-y) point in Q \intersect P otherwise, breaking ties by preferring smaller values of x
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def smallest_y_in_sw(x0, y0, open: false)
    flip @max_pst.largest_y_in_nw(x0, -y0, open:)
  end

  ########################################
  # Leftmost SE and Rightmost SW

  # Return the leftmost (min-x) point in P to the southeast of (x0, y0).
  #
  # Let Q = [x0, infty) X (infty, y0] be the southeast quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (infty, -infty) if Q \intersect P is empty and
  # - the leftmost (min-x) point in Q \intersect P otherwise.
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def smallest_x_in_se(x0, y0, open: false)
    flip @max_pst.smallest_x_in_ne(x0, -y0, open:)
  end

  # Return the rightmost (max-x) point in P to the southwest of (x0, y0).
  #
  # Let Q = (-infty, x0] X (infty, y0] be the southwest quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (-infty, -infty) if Q \intersect P is empty and
  # - the leftmost (min-x) point in Q \intersect P otherwise.
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def largest_x_in_sw(x0, y0, open: false)
    flip @max_pst.largest_x_in_nw(x0, -y0, open:)
  end

  ########################################
  # Lowest 3 Sided

  # Return the lowest point of P in the box bounded by x0, x1, and y0.
  #
  # Let Q = [x0, x1] X (infty, y0] be the "three-sided" box bounded by x0, x1, and y0, and let P be the set of points in the
  # MaxPST. (Note that Q is empty if x1 < x0.) Define p* as
  #
  # - (infty, infty) if Q \intersect P is empty and
  # - the highest (max-y) point in Q \intersect P otherwise, breaking ties by preferring smaller x values.
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def smallest_y_in_3_sided(x0, x1, y0, open: false)
    flip @max_pst.largest_y_in_3_sided(x0, x1, -y0, open:)
  end

  ########################################
  # Enumerate 3 sided

  # Enumerate the points of P in the box bounded by x0, x1, and y0.
  #
  # Let Q = [x0, x1] X [y0, infty) be the "three-sided" box bounded by x0, x1, and y0, and let P be the set of points in the
  # MaxPST. (Note that Q is empty if x1 < x0.) We find an enumerate all the points in Q \intersect P.
  #
  # If the calling code provides a block then we +yield+ each point to it. Otherwise we return a set containing all the points in
  # the intersection.
  #
  # This method runs in O(m + log n) time and O(1) extra space, where m is the number of points found.
  def enumerate_3_sided(x0, x1, y0, open: false)
    if block_given?
      @max_pst.enumerate_3_sided(x0, x1, -y0, open:) { |point| yield(flip point) }
    else
      Set.new( @max_pst.enumerate_3_sided(x0, x1, -y0, open:).map { |pt| flip pt })
    end
  end

  ########################################
  # Delete top

  # Delete the top (min-y) element of the PST. This is possible only for dynamic PSTs
  #
  # It runs in guaranteed O(log n) time, where n is the size of the PST when it was intially constructed. As elements are deleted
  # the internal tree structure is no longer guaranteed to be balanced and so we cannot guarantee operation in O(log n') time, where
  # n' is the current size. In practice, "random" deletion is likely to leave the tree almost balanced.
  #
  # @return [Point] the top element that was deleted
  def delete_top!
    flip @max_pst.delete_top!
  end

  # (x, y) -> (x, -y)
  private def flip(point)
    Point.new(point.x, -point.y)
  end
end
