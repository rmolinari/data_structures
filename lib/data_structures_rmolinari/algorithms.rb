# Algorithms that use the module's data structures but don't belong as a method on one of the data structures
module DataStructuresRMolinari::Algorithms
  include Shared

  # We are given a set P of points in the x-y plane. An _empty rectangle for P_ is a rectangle (left, right, bottom, top)
  # satisifying the following
  #   - it has positive area;
  #   - its sides are parallel to the axes;
  #   - it lies within the smallest bounding box (x_min, x_max, y_min, y_max) containing P; and
  #   - no point of P lies in its interior.
  #
  # A _maximal empty rectangle_ (MER) for P is an empty rectangle for P not properly contained in any other.
  #
  # We enumerate all maximal empty rectangles for P, yielding each as (left, right, bottom, top). The algorithm is due to De, M.,
  # Maheshwari, A., Nandy, S. C., Smid, M., _An In-Place Min-max Priority Search Tree_, Computational Geometry, v46 (2013), pp
  # 310-327.
  #
  # It runs in O(m log n) time, where m is the number of MERs enumerated and n is the number of points in P.  (Contructing the
  # MaxPST takes O(n log^2 n) time, but m = O(n^2) so we are still O(m log n) overall.)
  #
  # @param points [Array] an array of points in the x-y plane. Each must respond to +x+ and +y+.
  def self.maximal_empty_rectangles(points)
    # We break the emtpy rectangles into three types
    #   1. bounded at bottom and top by y_min and y_max
    #   2. bounded at the top by y_max and at the bottom by one of the points of P
    #   3. bounded at the top by a point in P

    return if points.size <= 1

    sorted_points = points.sort_by(&:x)
    x_min = sorted_points.first.x
    x_max = sorted_points.last.x
    y_min, y_max = sorted_points.map(&:y).minmax

    # Half of the smallest non-zero gap between x values. This is needed below
    epsilon = INFINITY

    # Enumerate type 1
    sorted_points.each_cons(2) do |pt1, pt2|
      next if pt1.x == pt2.x

      d = (pt2.x.to_f - pt1.x) / 2
      epsilon = d if d < epsilon

      yield [pt1.x, pt2.x, y_min, y_max]
    end

    # This builds its internal structure inside sorted_points itself.
    max_pst = DataStructuresRMolinari::MaxPrioritySearchTree.new(sorted_points, dynamic: true)

    # Enumerate type 2. We consider each point of P and work out the largest rectangle bounded below by P and above by y_max. The
    # points constraining us on the left and right are given by queries on the MaxPST.
    points.each do |pt|
      next if pt.y == y_max # 0 area
      next if pt.y == y_min # type 1

      # Epsilon means we don't just get pt back again. The De et al. paper is rather vague.
      left_bound  = max_pst.largest_x_in_nw( pt.x - epsilon, pt.y)
      right_bound = max_pst.smallest_x_in_ne(pt.x + epsilon, pt.y)

      left = left_bound.x.infinite? ? x_min : left_bound.x
      right = right_bound.x.infinite? ? x_max : right_bound.x
      next if left == right

      yield [left, right, pt.y, y_max]
    end

    # Enumerate type 3. This is the cleverest part of the algorithm. Start with a point (x0, y0) in P. We imagine a horizontal line
    # drawing down over the bounding rectangle, starting at y = y0 with l = x_min and r = x_max. Every time we meet another point
    # (x1, y1) of P we emit a maximal rectangle and shorten the horizonal line. At any time, the next point that we encounter is the
    # highest (max y) point in the region l < x < r and y >= y_min.
    #
    # If we have a MaxPST containing with the points (x0, y0) and above deleted, (x1, y1) is almost given by
    #
    #      largest_y_in_3_sided(l, r, y_min)
    #
    # That call considers the points in the closed region l <= x <= r and y >= y_min, so we use l + epsilon and r - epsilon.
    until max_pst.empty?
      top_pt = max_pst.delete_top!
      top = top_pt.y
      next if top == y_max # this one is type 1 or 2
      next if top == y_min # zero area: no good

      l = x_min
      r = x_max

      loop do
        next_pt = max_pst.largest_y_in_3_sided(l + epsilon, r - epsilon, y_min)

        bottom = next_pt.y.infinite? ? y_min : next_pt.y
        yield [l, r, bottom, top]

        break if next_pt.y.infinite? # we have reached the bottom

        if next_pt.x < top_pt.x
          l = next_pt.x
        else
          r = next_pt.x
        end
      end
    end
  end
end
