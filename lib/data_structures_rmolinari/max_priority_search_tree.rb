require 'must_be'
require 'set'
require_relative 'shared'

# A priority search tree (PST) stores a set, P, of two-dimensional points (x,y) in a way that allows efficient answers to certain
# questions about P.
#
# The data structure was introduced in 1985 by Edward McCreight. Later, De, Maheshwari, Nandy, and Smid showed how to construct a
# PST in-place (using only O(1) extra memory), at the expense of some slightly more complicated code for the various supported
# operations. It is their approach that we have implemented.
#
# The PST structure is an implicit, balanced binary tree with the following properties:
# * The tree is a _max-heap_ in the y coordinate. That is, the point at each node has a y-value no greater than its parent.
# * For each node p, the x-values of all the nodes in the left subtree of p are less than the x-values of all the nodes in the right
#   subtree of p. Note that this says nothing about the x-value at the node p itself. The tree is thus _almost_ a binary search tree
#   in the x coordinate.
#
# Given a set of n points, we can answer the following questions quickly:
#
# - +smallest_x_in_ne+: for x0 and y0, what is the leftmost point (x, y) in P satisfying x >= x0 and y >= y0?
# - +largest_x_in_nw+: for x0 and y0, what is the rightmost point (x, y) in P satisfying x <= x0 and y >= y0?
# - +largest_y_in_ne+: for x0 and y0, what is the highest point (x, y) in P satisfying x >= x0 and y >= y0?
# - +largest_y_in_nw+: for x0 and y0, what is the highest point (x, y) in P satisfying x <= x0 and y >= y0?
# - +largest_y_in_3_sided+: for x0, x1, and y0, what is the highest point (x, y) in P satisfying x >= x0, x <= x1 and y >= y0?
# - +enumerate_3_sided+: for x0, x1, and y0, enumerate all points in P satisfying x >= x0, x <= x1 and y >= y0.
#
# (Here, "leftmost/rightmost" means "minimal/maximal x", and "highest" means "maximal y".)
#
# The first 5 operations take O(log n) time.
#
# The final operation (enumerate) takes O(m + log n) time, where m is the number of points that are enumerated.
#
# In the current implementation no two points can share an x-value. This restriction can be relaxed with some more complicated code,
# but it hasn't been written yet. See issue #9.
#
# There is a related data structure called the Min-max priority search tree so we have called this a "Max priority search tree", or
# MaxPST.
#
# References:
# * E.M. McCreight, _Priority search trees_, SIAM J. Comput., 14(2):257-276, 1985.
# * M. De, A. Maheshwari, S. C. Nandy, M. Smid, _An In-Place Priority Search Tree_, 23rd Canadian Conference on Computational
#   Geometry, 2011
class DataStructuresRMolinari::MaxPrioritySearchTree
  include Shared
  include BinaryTreeArithmetic

  # Construct a MaxPST from the collection of points in +data+.
  #
  # @param data [Array] the set P of points presented as an array. The tree is built in the array in-place without cloning.
  #   - Each element of the array must respond to +#x+ and +#y+.
  #     - This is not checked explicitly but a missing method exception will be thrown when we try to call one of them.
  #   - The +x+ values must be distinct. We raise a +Shared::DataError+ if this isn't the case.
  #     - This is a restriction that simplifies some of the algorithm code. It can be removed as the cost of some extra work. Issue
  #       #9.
  # @param dynamic [Boolean] when truthy the PST is _dynamic_. This means the root can be deleted, which is useful in certain
  #        algorithms than use a PST.
  #        - a dynamic PST needs more bookwork for some internal work and so slows things down a little.
  # @param verify [Boolean] when truthy, check that the properties of a PST are satisified after construction, raising an exception
  #        if not.
  def initialize(data, dynamic: false, verify: false)
    @data = data
    @size = @data.size
    @member_count = @size # these can diverge for dynamic PSTs
    @dynamic = dynamic

    construct_pst

    verify_properties if verify
  end

  def empty?
    @member_count.zero?
  end

  ########################################
  # Highest NE and Highest NW

  # Return the highest point in P to the "northeast" of (x0, y0).
  #
  # Let Q = [x0, infty) X [y0, infty) be the northeast quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (infty, -infty) if Q \intersect P is empty and
  # - the highest (max-y) point in Q \intersect P otherwise, breaking ties by preferring smaller values of x
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def largest_y_in_ne(x0, y0)
    largest_y_in_quadrant(x0, y0, :ne)
  end

  # Return the highest point in P to the "northwest" of (x0, y0).
  #
  # Let Q = (-infty, x0] X [y0, infty) be the northwest quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (-infty, -infty) if Q \intersect P is empty and
  # - the highest (max-y) point in Q \intersect P otherwise, breaking ties by preferring smaller values of x
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def largest_y_in_nw(x0, y0)
    largest_y_in_quadrant(x0, y0, :nw)
  end

  # The basic algorithm is from De et al. section 3.1. We have generalaized it slightly to allow it to calculate both largest_y_in_ne and
  # largest_y_in_nw
  #
  # Note that largest_y_in_ne(x0, y0) = largest_y_in_3_sided(x0, infinty, y0) so we don't really need this. But it's a bit faster than the
  # general case and is a simple algorithm that introduces a typical way that an algorithm interacts with the data structure.
  #
  # From the paper:
  #
  #   The algorithm uses two variables best and p, which satisfy the following invariant
  #
  #     - If Q intersect P is nonempty then p* in {best} union T_p
  #     - If Q intersect P is empty then p* = best
  #
  # Here, P is the set of points in our data structure and T_p is the subtree rooted at p
  private def largest_y_in_quadrant(x0, y0, quadrant)
    quadrant.must_be_in [:ne, :nw]

    p = root
    if quadrant == :ne
      best = Point.new(INFINITY, -INFINITY)
      preferred_child = ->(n) { right(n) }
      nonpreferred_child = ->(n) { left(n) }
      sufficient_x = ->(x) { x >= x0 }
    else
      best = Point.new(-INFINITY, -INFINITY)
      preferred_child = ->(n) { left(n) }
      nonpreferred_child = ->(n) { right(n) }
      sufficient_x = ->(x) { x <= x0 }
    end

    # x == x0 or is not sufficient. This test sometimes excludes the other child of a node from consideration.
    exclusionary_x = ->(x) { x == x0 || !sufficient_x.call(x) }

    in_q = lambda do |pair|
      sufficient_x.call(pair.x) && pair.y >= y0
    end

    # From the paper:
    #
    #   takes as input a point t and does the following: if t \in Q and y(t) > y(best) then it assignes best = t
    #
    # We break ties by preferring points with smaller x values
    update_highest = lambda do |node|
      t = @data[node]
      if in_q.call(t) && (t.y > best.y || (t.y == best.y && t.x < best.x))
        best = t
      end
    end

    # We could make this code more efficient. But since we only have O(log n) steps we won't actually gain much so let's keep it
    # readable and close to the paper's pseudocode for now.
    until leaf?(p)
      p_val = @data[p]
      if in_q.call(p_val)
        # p \in Q and nothing in its subtree can beat it because of the max-heap
        update_highest.call(p)
        return best
      elsif p_val.y < y0
        # p is too low for Q, so the entire subtree is too low as well
        return best
      elsif (child = one_child?(p))
        # With just one child we need to check it
        p = child
      elsif exclusionary_x.call(@data[preferred_child.call(p)].x)
        # right(p) might be in Q, but nothing in the left subtree can be, by the PST property on x.
        p = preferred_child.call(p)
      elsif sufficient_x.call(@data[nonpreferred_child.call(p)].x)
        # Both children have sufficient x, so try the y-higher of them. Note that nothing else in either subtree will beat this one,
        # by the y-property of the PST
        higher = left(p)
        if @data[right(p)].y > @data[left(p)].y
          higher = right(p)
        end
        p = higher
      elsif @data[preferred_child.call(p)].y < y0
        # Nothing in the right subtree is in Q, but maybe we'll find something in the left
        p = nonpreferred_child.call(p)
      else
        # At this point we know that right(p) \in Q so we need to check it. Nothing in its subtree can beat it so we don't need to
        # look there. But there might be something better in the left subtree.
        update_highest.call(preferred_child.call(p))
        p = nonpreferred_child.call(p)
      end
    end
    update_highest.call(p) # try the leaf
    best
  end

  ########################################
  # Leftmost NE and Rightmost NW

  # Return the leftmost (min-x) point in P to the northeast of (x0, y0).
  #
  # Let Q = [x0, infty) X [y0, infty) be the northeast quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (infty, infty) if Q \intersect P is empty and
  # - the leftmost (min-x) point in Q \intersect P otherwise.
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def smallest_x_in_ne(x0, y0)
    extremal_in_x_dimension(x0, y0, :ne)
  end

  # Return the rightmost (max-x) point in P to the northwest of (x0, y0).
  #
  # Let Q = (-infty, x0] X [y0, infty) be the northwest quadrant defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (-infty, infty) if Q \intersect P is empty and
  # - the leftmost (min-x) point in Q \intersect P otherwise.
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def largest_x_in_nw(x0, y0)
    extremal_in_x_dimension(x0, y0, :nw)
  end

  # A genericized version of the paper's smallest_x_in_ne that can calculate either smallest_x_in_ne or largest_x_in_nw as specifies via a
  # parameter.
  #
  # Quadrant is either :ne (which gives smallest_x_in_ne) or :nw (which gives largest_x_in_nw).
  #
  # From De et al:
  #
  #   The algorithm uses three variables best, p, and q which satisfy the folling invariant:
  #
  #     - if Q \intersect P is empty then p* = best
  #     - if Q \intersect P is nonempty then  p* \in {best} \union T(p) \union T(q)
  #     - p and q are at the same level of T and x(p) <= x(q)
  private def extremal_in_x_dimension(x0, y0, quadrant)
    quadrant.must_be_in [:ne, :nw]

    if quadrant == :ne
      sign = 1
      best = Point.new(INFINITY, INFINITY)
    else
      sign = -1
      best = Point.new(-INFINITY, INFINITY)
    end

    p = q = root

    in_q = lambda do |pair|
      sign * pair.x >= sign * x0 && pair.y >= y0
    end

    # From the paper:
    #
    #   takes as input a point t and does the following: if t \in Q and x(t) < x(best) then it assignes best = t
    #
    # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
    update_best = lambda do |node|
      t = @data[node]
      if in_q.call(t) && sign * t.x < sign * best.x
        best = t
      end
    end

    # Use the approach described in the Min-Max paper, p 316
    #
    # In the paper c = [c1, c2, ..., ck] is an array of four nodes, [left(p), right(p), left(q), right(q)], but we also use this
    # logic when q has only a left child.
    #
    # Idea: x(c1) < x(c2) < ..., so the key thing to know for the next step is where x0 fits in.
    #
    # - If x0 <= x(c1) then all subtrees have large enough x values and we look for the leftmost node in c with a large enough y
    #   value. Both p and q are sent into that subtree.
    # - If x0 >= x(ck) the the rightmost subtree is our only hope
    # - Otherwise, x(c1) < x0 < x(ck) and we let i be least so that x(ci) <= x0 < x(c(i+1)). Then q becomes the lefmost cj in c not
    #   to the left of ci such that y(cj) >= y0, if any. p becomes ci if y(ci) >= y0 and q otherwise. If there is no such j, we put
    #   q = p. This may leave both of p, q undefined which means there is no useful way forward and we return nils to signal this to
    #   calling code.
    #
    # The same logic applies to largest_x_in_nw, though everything is "backwards"
    # - membership of Q depends on having a small-enough value of x, rather than a large-enough one
    # - among the ci, values towards the end of the array tend not to be in Q while values towards the start of the array tend to be
    #  in Q
    #
    # Idea: handle the first issue by negating all x-values being compared and handle the second by reversing the array c before
    # doing anything and swapping the values for p and q that we work out.
    determine_next_nodes = lambda do |*c|
      c.reverse! if quadrant == :nw

      if sign * @data[c.first].x > sign * x0
        # All subtrees have x-values good enough for Q. We look at y-values to work out which subtree to focus on
        leftmost = c.find { |node| @data[node].y >= y0 } # might be nil

        # Otherwise, explore the "leftmost" subtree with large enough y values. Its root is in Q and can't be beaten as "leftmost"
        # by anything to its "right". If it's nil the calling code can bail
        return [leftmost, leftmost]
      end

      if sign * @data[c.last].x <= sign * x0
        # only the "rightmost" subtree can possibly have anything in Q, assuming distinct x-values
        return [c.last, c.last]
      end

      values = c.map { |node| @data[node] }

      # Note that x(c1) <= x0 < x(c4) so i is well-defined
      i = (0...4).find { |j| sign * values[j].x <= sign * x0 && sign * x0 < sign * values[j + 1].x }

      # These nodes all have large-enough x values so looking at y finds the ones in Q
      new_q = c[(i + 1)..].find { |node| @data[node].y >= y0 } # could be nil
      new_p = c[i] if values[i].y >= y0 # The leftmost subtree is worth exploring if the y-value is big enough but not otherwise
      new_p ||= new_q # if nodes[i] is no good, send p along with q
      new_q ||= new_p # but if there is no worthwhile value for q we should send it along with p

      return [new_q, new_p] if quadrant == :nw # swap for the largest_x_in_nw case.

      [new_p, new_q]
    end

    # Now that we have the possibility of dynamic PSTs we need to worry about more cases. For example, p might be a leaf even though
    # q is not
    until leaf?(p) && leaf?(q)
      update_best.call(p)
      update_best.call(q)

      if p == q
        if (child = one_child?(p))
          p = q = child
        else
          q = right(p)
          p = left(p)
        end
      else
        # p != q
        if leaf?(q)
          q = p
        elsif leaf?(p)
          p = q
        else
          p_only_child = one_child?(p)
          q_only_child = one_child?(q)
          # This generic approach is not as fast as the bespoke checks described in the paper. But it is easier to maintain the code
          # this way and allows easy implementation of largest_x_in_nw
          if p_only_child && q_only_child
            p, q = determine_next_nodes.call(p_only_child, q_only_child)
          elsif p_only_child
            p, q = determine_next_nodes.call(p_only_child, left(q), right(q))
          elsif q_only_child
            p, q = determine_next_nodes.call(left(p), right(p), q_only_child)
          else
            p, q = determine_next_nodes.call(left(p), right(p), left(q), right(q))
          end
        end
        break unless p # we've run out of useful nodes
      end
    end
    update_best.call(p) if p
    update_best.call(q) if q
    best
  end

  ########################################
  # Highest 3 Sided

  # Return the highest point of P in the box bounded by x0, x1, and y0.
  #
  # Let Q = [x0, x1] X [y0, infty) be the "three-sided" box bounded by x0, x1, and y0, and let P be the set of points in the
  # MaxPST. (Note that Q is empty if x1 < x0.) Define p* as
  #
  # - (infty, -infty) if Q \intersect P is empty and
  # - the highest (max-y) point in Q \intersect P otherwise, breaking ties by preferring smaller x values.
  #
  # This method returns p* in O(log n) time and O(1) extra space.
  def largest_y_in_3_sided(x0, x1, y0)
    # From the paper:
    #
    #    The three real numbers x0, x1, and y0 define the three-sided range Q = [x0,x1] X [y0,∞). If Q \intersect P̸ is not \empty,
    #    define p* to be the highest point of P in Q. If Q \intersect P = \empty, define p∗ to be the point (infty, -infty).
    #    Algorithm Highest3Sided(x0,x1,y0) returns the point p∗.
    #
    #    The algorithm uses two bits L and R, and three variables best, p, and q. As before, best stores the highest point in Q
    #    found so far. The bit L indicates whether or not p∗ may be in the subtree of p; if L=1, then p is to the left of
    #    Q. Similarly, the bit R indicates whether or not p∗ may be in the subtree of q; if R=1, then q is to the right of Q.
    #
    # Although there are a lot of lines and cases the overall idea is simple. We maintain in p the rightmost node at its level that
    # is to the left of the area Q. Likewise, q is the leftmost node that is the right of Q. The logic just updates this data at
    # each step. The helper check_left updates p and check_right updates q.
    #
    # A couple of simple observations that show why maintaining just these two points is enough.
    #
    # - We know that x(p) < x0. This tells us nothing about the x values in the subtrees of p (which is why we need to check various
    #   cases), but it does tell us that everything to the left of p has values of x that are too small to bother with.
    # - We don't need to maintain any state inside the region Q because the max-heap property means that if we ever find a node r in
    #   Q we check it for best and then ignore its subtree (which cannot beat r on y-value).
    #
    # Sometimes we don't have a relevant node to the left or right of Q. The booleans L and R (which we call left and right) track
    # whether p and q are defined at the moment.
    best = Point.new(INFINITY, -INFINITY)
    p = q = left = right = nil

    x_range = (x0..x1)

    in_q = lambda do |pair|
      x_range.cover?(pair.x) && pair.y >= y0
    end

    # From the paper:
    #
    #   takes as input a point t and does the following: if t \in Q and x(t) < x(best) then it assignes best = t
    #
    # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
    update_highest = lambda do |node|
      t = @data[node]
      if in_q.call(t) && (t.y > best.y || (t.y == best.y && t.x < best.x))
        best = t
      end
    end

    # "Input: a node p such that x(p) < x0""
    #
    # Step-by-step it is pretty straightforward. As the paper says
    #
    #   [E]ither p moves one level down in the tree T or the bit L is set to 0. In addition, the point q either stays the same or it
    #   become a child of (the original) p.
    check_left = lambda do
      if leaf?(p)
        left = false
      elsif (only_child = one_child?(p))
        if x_range.cover? @data[only_child].x
          update_highest.call(only_child)
          left = false # can't do y-better in the subtree
        elsif @data[only_child].x < x0
          p = only_child
        else
          q = only_child
          right = true
          left = false
        end
      else
        # p has two children
        if @data[left(p)].x < x0
          if @data[right(p)].x < x0
            p = right(p)
          elsif @data[right(p)].x <= x1
            update_highest.call(right(p))
            p = left(p)
          else
            # x(p_r) > x1, so q needs to take it
            q = right(p)
            p = left(p)
            right = true
          end
        elsif @data[left(p)].x <= x1
          update_highest.call(left(p))
          left = false # we won't do better in T(p_l)
          if @data[right(p)].x > x1
            q = right(p)
            right = true
          else
            update_highest.call(right(p))
          end
        else
          q = left(p)
          left = false
          right = true
        end
      end
    end

    # Do "on the right" with q what check_left does on the left with p
    #
    # We know that x(q) > x1
    #
    # TODO: can we share logic between check_left and check_right? At first glance they are too different to parameterize but maybe
    # the bones can be shared.
    #
    # We either push q further down the tree or make right = false. We might also make p a child of (original) q. We never change
    # left from true to false
    check_right = lambda do
      if leaf?(q)
        right = false
      elsif (only_child = one_child?(q))
        if x_range.cover? @data[only_child].x
          update_highest.call(only_child)
          right = false # can't do y-better in the subtree
        elsif @data[only_child].x < x0
          p = only_child
          left = true
          right = false
        else
          q = only_child
        end
      else
        # q has two children
        if @data[left(q)].x < x0
          left = true
          if @data[right(q)].x < x0
            p = right(q)
            right = false
          elsif @data[right(q)].x <= x1
            update_highest.call(right(q))
            p = left(q)
            right = false
          else
            # x(q_r) > x1
            p = left(q)
            q = right(q)
            # left = true
          end
        elsif @data[left(q)].x <= x1
          update_highest.call(left(q))
          if @data[right(q)].x > x1
            q = right(q)
          else
            update_highest.call(right(q))
            right = false
          end
        else
          q = left(q)
        end
      end
    end

    return best if empty?

    root_val = @data[root]

    # If the root value is in the region Q, the max-heap property on y means we can't do better
    if x_range.cover? root_val.x
      # If y(root) is large enough then the root is the winner because of the max heap property in y. And if it isn't large enough
      # then no other point in the tree can be high enough either
      left = right = false
      best = root_val if root_val.y >= y0
    end

    if root_val.x < x0
      p = root
      left = true
      right = false
    else
      q = root
      left = false
      right = true
    end

    val = ->(sym) { sym == :left ? p : q }

    while left || right
      set_i = []
      set_i << :left if left
      set_i << :right if right
      z = set_i.min_by { |s| level(val.call(s)) }
      if z == :left
        check_left.call
      else
        check_right.call
      end
    end

    best
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
  def enumerate_3_sided(x0, x1, y0)
    # From the paper
    #
    #     Given three real numbers x0, x1, and y0 define the three sided range Q = [x0, x1] X [y0, infty). Algorithm
    #     Enumerage3Sided(x0, x1,y0) returns all elements of Q \intersect P. The algorithm uses the same approach as algorithm
    #     Highest3Sided. Besides the two bits L and R it uses two additional bits L' and R'. Each of these four bits ... corresponds
    #     to a subtree of T rooted at the points p, p', q, and q', respectively; if the bit is equal to one, then the subtree may
    #     contain points that are in the query range Q.
    #
    #     The following variant will be maintained:
    #
    #     - If L = 1 then x(p) < x0.
    #     - If L' = 1 then x0 <= x(p') <= x1.
    #     - If R = 1 then x(q) > x1.
    #     - If R' = 1 then x0 <= x(q') <= x1.
    #     - If L' = 1 and R' = 1 then x(p') <= x(q').
    #     - All points in Q \intersect P [other than those in the subtrees of the currently active search nodes] have been reported.
    #
    #
    # My high-level understanding of the algorithm
    # --------------------------------------------
    #
    # We need to find all elements of Q \intersect P, so it isn't enough, as it was in largest_y_in_3_sided simply to keep track of p and
    # q. We need to track four nodes, p, p', q', and q which are (with a little handwaving) respectively
    #
    # - the rightmost node to the left of Q' = [x0, x1] X [-infinity, infinity],
    # - the leftmost node inside Q',
    # - the rightmost node inside Q', and
    # - the leftmost node to the right of Q'.
    #
    # Tracking these is enough. Subtrees of things to the left of p can't have anything in Q by the x-value properties of the PST,
    # and likewise with things to the right of q.
    #
    # And we don't need to track any more nodes inside Q'. If we had r with p' <~ r <~ q' (where s <~ t represents "t is to the
    # right of s"), then all of the subtree rooted at r lies inside Q', and we can visit all of its elements of Q \intersect P via
    # the routine Explore(), which is what we do whenever we need to. The node r is thus exhausted, and we can forget about it.
    #
    # So the algorithm is actually quite simple. There is a large amount of code here because of the many cases that need to be
    # handled at each update.
    #
    # If a block is given, yield each found point to it. Otherwise return all the found points in an enumerable (currently Set).
    x_range = x0..x1
    # Instead of using primes we use "_in"
    left = left_in = right_in = right = false
    p = p_in = q_in = q = nil

    result = Set.new

    report = lambda do |node|
      if block_given?
        yield @data[node]
      else
        result << @data[node]
      end
    end

    # "reports all points in T_t whose y-coordinates are at least y0"
    #
    # We follow the logic from the min-max paper, leaving out the need to worry about the parity of the leval and the min- or max-
    # switching.
    explore = lambda do |t|
      current = t
      state = 0
      while current != t || state != 2
        case state
        when 0
          # State 0: we have arrived at this node for the first time
          # look at current and perhaps descend to left child
          # The paper describes this algorithm as in-order, but isn't this pre-order?
          if @data[current].y >= y0
            report.call(current)
          end
          if !leaf?(current) && in_tree?(left(current)) && @data[left(current)].y >= y0
            current = left(current)
          else
            state = 1
          end
        when 1
          # State 1: we've already handled this node and its left subtree. Should we descend to the right subtree?
          if in_tree?(right(current)) && @data[right(current)].y >= y0
            current = right(current)
            state = 0
          else
            state = 2
          end
        when 2
          # State 2: we're done with this node and its subtrees. Go back up a level, having set state correctly for the logic at the
          # parent node.
          if left_child?(current)
            state = 1
          end
          current = parent(current)
        else
          raise InternalLogicError, "Explore(t) state is somehow #{state} rather than 0, 1, or 2."
        end
      end
    end

    # Helpers for the helpers
    #
    # Invariant: if q_in is active then p_in is active. In other words, if only one "inside" node is active then it is p_in.

    # Mark p_in as inactive. Then, if q_in is active, it becomes p_in.
    deactivate_p_in = lambda do
      left_in = false
      return unless right_in

      p_in = q_in
      left_in = true
      right_in = false
    end

    # Add a new leftmost "in" point. This becomes p_in. We handle existing "inside" points appropriately
    add_leftmost_inner_node = lambda do |node|
      if left_in && right_in
        # the old p_in is squeezed between node and q_in
        explore.call(p_in)
      elsif left_in
        q_in = p_in
        right_in = true
      else
        left_in = true
      end
      p_in = node
    end

    add_rightmost_inner_node = lambda do |node|
      if left_in && right_in
        # the old q_in is squeezed between p_in and node
        explore.call(q_in)
        q_in = node
      elsif left_in
        q_in = node
        right_in = true
      else
        p_in = node
        left_in = true
      end
    end

    ########################################
    # The four key helpers described in the paper

    # Handle the next step of the subtree at p
    enumerate_left = lambda do
      if leaf?(p)
        left = false
        return
      end

      if (only_child = one_child?(p))
        child_val = @data[only_child]
        if x_range.cover? child_val.x
          add_leftmost_inner_node.call(only_child)
          left = false
        elsif child_val.x < x0
          p = only_child
        else
          q = only_child
          right = true
          left = false
        end
        return
      end

      # p has two children
      if @data[left(p)].x < x0
        if @data[right(p)].x < x0
          p = right(p)
        elsif @data[right(p)].x <= x1
          add_leftmost_inner_node.call(right(p))
          p = left(p)
        else
          q = right(p)
          p = left(p)
          right = true
        end
      elsif @data[left(p)].x <= x1
        if @data[right(p)].x > x1
          q = right(p)
          p_in = left(p)
          left = false
          left_in = right = true
        else
          # p_l and p_r both lie inside [x0, x1]
          add_leftmost_inner_node.call(right(p))
          add_leftmost_inner_node.call(left(p))
          left = false
        end
      else
        q = left(p)
        left = false
        right = true
      end
    end

    # Given: p' satisfied x0 <= x(p') <= x1. (Our p_in is the paper's p')
    enumerate_left_in = lambda do
      if @data[p_in].y >= y0
        report.call(p_in)
      end

      if leaf?(p_in) # nothing more to do
        deactivate_p_in.call
        return
      end

      if (only_child = one_child?(p_in))
        child_val = @data[only_child]
        if x_range.cover? child_val.x
          p_in = only_child
        elsif child_val.x < x0
          # We aren't in the [x0, x1] zone any more and have moved out to the left
          p = only_child
          deactivate_p_in.call
          left = true
        else
          # similar, but we've moved out to the right. Note that left(p_in) is the leftmost node to the right of Q.
          raise 'q_in should not be active (by the val of left(p_in))' if right_in

          q = only_child
          deactivate_p_in.call
          right = true
        end
      else
        # p' has two children
        left_val = @data[left(p_in)]
        right_val = @data[right(p_in)]
        if left_val.x < x0
          if right_val.x < x0
            p = right(p_in)
            left = true
            deactivate_p_in.call
          elsif right_val.x <= x1
            p = left(p_in)
            p_in = right(p_in)
            left = true
          else
            raise InternalLogicError, 'q_in cannot be active, by the value in the right child of p_in!' if right_in

            p = left(p_in)
            q = right(p_in)
            deactivate_p_in.call
            left = true
            right = true
          end
        elsif left_val.x <= x1
          if right_val.x > x1
            raise InternalLogicError, 'q_in cannot be active, by the value in the right child of p_in!' if right_in

            q = right(p_in)
            p_in = left(p_in)
            right = true
          elsif right_in
            explore.call(right(p_in))
            p_in = left(p_in)
          else
            q_in = right(p_in)
            p_in = left(p_in)
            right_in = true
          end
        else
          raise InternalLogicError, 'q_in cannot be active, by the value in the right child of p_in!' if right_in

          q = left(p_in)
          deactivate_p_in.call
          right = true
        end
      end
    end

    # This is "just like" enumerate left, but handles q instead of p.
    #
    # The paper doesn't given an implementation, but it should be pretty symmetric. Can we share any logic with enumerate_left?
    #
    # Q: why is my implementation more complicated than enumerate_left? I must be missing something.
    enumerate_right = lambda do
      if leaf?(q)
        right = false
        return
      end

      if (only_child = one_child?(q))
        child_val = @data[only_child]
        if x_range.cover? child_val.x
          add_rightmost_inner_node.call(only_child)
          right = false
        elsif child_val.x < x0
          p = only_child
          left = true
          right = false
        else
          q = only_child
        end
        return
      end

      # q has two children. Cases!
      if @data[left(q)].x < x0
        raise InternalLogicError, 'p_in should not be active, based on the value at left(q)' if left_in
        raise InternalLogicError, 'q_in should not be active, based on the value at left(q)' if right_in

        left = true
        if @data[right(q)].x < x0
          p = right(q)
          right = false
        elsif @data[right(q)].x <= x1
          p_in = right(q)
          p = left(q)
          left_in = true
          right = false
        else
          p = left(q)
          q = right(q)
        end
      elsif @data[left(q)].x <= x1
        add_rightmost_inner_node.call(left(q))
        if @data[right(q)].x > x1
          q = right(q)
        else
          add_rightmost_inner_node.call(right(q))
          right = false
        end
      else
        # x(q_l) > x1
        q = left(q)
      end
    end

    # Given: q' is active and satisfied x0 <= x(q') <= x1
    enumerate_right_in = lambda do
      raise InternalLogicError, 'right_in should be true if we call enumerate_right_in' unless right_in

      if @data[q_in].y >= y0
        report.call(q_in)
      end

      if leaf?(q_in)
        right_in = false
        return
      end

      if (only_child = one_child?(q_in))
        child_val = @data[only_child]
        if x_range.cover? child_val.x
          q_in = only_child
        elsif child_val.x < x0
          # We have moved out to the left
          p = only_child
          right_in = false
          left = true
        else
          # We have moved out to the right
          q = only_child
          right_in = false
          right = true
        end
        return
      end

      # q' has two children
      left_val = @data[left(q_in)]
      right_val = @data[right(q_in)]
      if left_val.x < x0
        raise InternalLogicError, 'p_in cannot be active, by the value in the left child of q_in' if left_in

        if right_val.x < x0
          p = right(q_in)
        elsif right_val.x <= x1
          p = left(q_in)
          p_in = right(q_in) # should this be q_in = right(q_in) ??
          left_in = true
        else
          p = left(q_in)
          q = right(q_in)
          right = true
        end
        right_in = false
        left = true
      elsif left_val.x <= x1
        if right_val.x > x1
          q = right(q_in)
          right = true
          if left_in
            q_in = left(q_in)
          else
            p_in = left(q_in)
            left_in = true
            right_in = false
          end
        else
          if left_in
            explore.call(left(q_in))
          else
            p_in = left(q_in)
            left_in = true
          end
          q_in = right(q_in)
        end
      else
        q = left(q_in)
        right_in = false
        right = true
      end
    end

    val = ->(sym) { { left: p, left_in: p_in, right_in: q_in, right: q }[sym] }

    root_val = @data[root]
    if root_val.y < y0
      # no hope, no op
    elsif root_val.x < x0
      p = root
      left = true
    elsif root_val.x <= x1 # Possible bug in paper, which tests "< x1"
      p_in = root
      left_in = true
    else
      q = root
      right = 1
    end

    while left || left_in || right_in || right
      raise InternalLogicError, 'It should not be that q_in is active but p_in is not' if right_in && !left_in

      set_i = []
      set_i << :left if left
      set_i << :left_in if left_in
      set_i << :right_in if right_in
      set_i << :right if right
      z = set_i.min_by { |sym| level(val.call(sym)) }
      case z
      when :left
        enumerate_left.call
      when :left_in
        enumerate_left_in.call
      when :right_in
        enumerate_right_in.call
      when :right
        enumerate_right.call
      else
        raise InternalLogicError, "bad symbol #{z}"
      end
    end
    return result unless block_given?
  end

  ########################################
  # Delete Top
  #

  # Delete the top element of the PST. This is possible only for dynamic PSTs
  #
  # @return [Point] the top element that was deleted
  def delete_top!
    raise LogicError, 'delete_top! not supported for PSTs that are not dynamic' unless dynamic?
    raise DataError, 'delete_top! not possible for empty PSTs' unless @member_count.positive?

    i = root
    while !leaf?(i)
      if (child = one_child?(i))
        next_node = child
      else
        next_node = left(i)

        if better_y?(right(i), next_node)
          next_node = right(i)
        end
      end
      swap(i, next_node)
      i = next_node
    end
    @member_count -= 1
    @data[i]
  end

  ########################################
  # Helpers for the internal guts of things

  private def dynamic?
    @dynamic
  end

  # i has no children
  private def leaf?(i)
    return i > @last_non_leaf unless dynamic?

    !(in_tree?(left(i)) || in_tree?(right(i)))
  end

  # i has exactly one child. We return the unique child if there is one, and nil otherwise

  # Unless the PST is dynamic this will be the left child. Otherwise it could be either
  private def one_child?(i)
    if dynamic?
      l_child = left(i)
      r_child = right(i)
      left_is_in_tree = in_tree?(l_child)
      return nil unless left_is_in_tree ^ in_tree?(r_child)
      return l_child if left_is_in_tree

      r_child
    else
      return left(i) if i == @parent_of_one_child

      nil
    end
  end

  # i has two children
  private def two_children?(i)
    i <= @last_parent_of_two_children unless dynamic?

    in_tree?(left(i)) && in_tree?(right(i))
  end

  # Does the value at index i have a "better" y value than the value at index j.
  #
  # A value is better if it is larger, or if it is equal and the x value is smaller (which is how we break the tie)
  private def better_y?(i, j)
    val_i = @data[i]
    val_j = @data[j]
    return true if val_i.y > val_j.y
    return false if val_i.y < val_j.y

    val_i.x < val_j.x
  end

  # Is node i in the tree?
  private def in_tree?(i)
    return i <= @size unless dynamic?

    return false if empty?
    return false if i > @size
    return true if i == root

    better_y?(parent(i), i)

    # p = parent(i)
    # return true if @data[i].y < @data[p].y
    # return false if @data[i].y > @data[p].y

    # # the y values are equal so the tie is broken by x. We are "normal", and in the tree, if our value of x is worse than our
    # # parent's value
    # @data[i].x > @data[p].x
  end

  ########################################
  # Build the initial stucture

  private def construct_pst
    raise DataError, 'Duplicate x values are not supported' if contains_duplicates?(@data, by: :x)

    # We follow the algorithm in the paper by De, Maheshwari et al, which takes O(n log^2 n) time. Their follow-up paper that
    # defines the Min-max PST, describes how to do the construction in O(n log n) time, but it is more complex and probably not
    # worth the trouble of both a bespoke heapsort the special sorting algorithm of Katajainen and Pasanen.

    # Since we are building an implicit binary tree, things are simpler if the array is 1-based. This requires a malloc (perhaps)
    # and memcpy (for sure), which isn't great, but it's in the C layer so cheap compared to the O(n log^2 n) work we need to do for
    # construction.
    @data.unshift nil

    h = Math.log2(@size).floor
    a = @size - (2**h - 1) # the paper calls it A
    sort_subarray(1, @size)

    @last_non_leaf = @size / 2
    if @size.even?
      @parent_of_one_child = @last_non_leaf
      @last_parent_of_two_children = @parent_of_one_child - 1
    else
      @parent_of_one_child = nil
      @last_parent_of_two_children = @last_non_leaf
    end

    (0...h).each do |i|
      pow_of_2 = 2**i
      k = a / (2**(h - i))
      k1 = 2**(h + 1 - i) - 1
      k2 = (1 - k) * 2**(h - i) - 1 + a
      k3 = 2**(h - i) - 1
      (1..k).each do |j|
        l = index_with_largest_y_in(
          pow_of_2 + (j - 1) * k1, pow_of_2 + j * k1 - 1
        )
        swap(l, pow_of_2 + j - 1)
      end

      if k < pow_of_2
        l = index_with_largest_y_in(
          pow_of_2 + k * k1, pow_of_2 + k * k1 + k2 - 1
        )
        swap(l, pow_of_2 + k)

        m = pow_of_2 + k * k1 + k2
        (1..(pow_of_2 - k - 1)).each do |j|
          l = index_with_largest_y_in(
            m + (j - 1) * k3, m + j * k3 - 1
          )
          swap(l, pow_of_2 + k + j)
        end
      end
      sort_subarray(2 * pow_of_2, @size)
    end
  end

  private def swap(index1, index2)
    return if index1 == index2

    @data[index1], @data[index2] = @data[index2], @data[index1]
  end

  # The index in @data[l..r] having the largest value for y, breaking ties with the smaller x value. Since we are already sorted by
  # x we don't actually need to check the x value.
  private def index_with_largest_y_in(l, r)
    return nil if r < l

    (l..r).max_by { |idx| @data[idx].y }
  end

  # Sort the subarray @data[l..r].
  private def sort_subarray(l, r)
    return if l == r # 1-array already sorted!

    # This slice-replacement is much faster than a Ruby-layer heapsort because it is mostly happening in C.
    @data[l..r] = @data[l..r].sort_by(&:x)
  end

  ########################################
  # Debugging support
  #
  # These methods are not written for speed

  # Check that our data satisfies the requirements of a Priority Search Tree:
  # - max-heap in y
  # - all the x values in the left subtree are less than all the x values in the right subtree
  private def verify_properties
    # It's a max-heap in y
    (2..@size).each do |node|
      byebug unless @data[node].y <= @data[parent(node)].y
      raise InternalLogicError, "Heap property violated at child #{node}" unless @data[node].y <= @data[parent(node)].y
    end

    # Left subtree has x values less than all of the right subtree
    (1..@size).each do |node|
      next if right(node) >= @size

      left_max = max_x_in_subtree(left(node))
      right_min = min_x_in_subtree(right(node))

      raise InternalLogicError, "Left-right property of x-values violated at #{node}" unless left_max < right_min
    end
  end

  private def max_x_in_subtree(root)
    return -Float::INFINITY if root >= @size

    [@data[root].x, max_x_in_subtree(left(root)), max_x_in_subtree(right(root))].max
  end

  private def min_x_in_subtree(root)
    return Float::INFINITY if root >= @size

    [@data[root].x, min_x_in_subtree(left(root)), min_x_in_subtree(right(root))].min
  end
end
