# A priority search tree stores points in two dimensions (x,y) and can efficiently answer certain questions about the set of point.
#
# It is a binary search tree which is a max-heap by the y-coordinate, and, for a non-leaf node N storing (x, y), all the nodes in
# the left subtree of N have smaller x values than any of the nodes in the right subtree of N. Note, though, that the x-value at N
# has no particular property relative to the x values in its subtree. It is thus _almost_ a binary search tree in the x coordinate.
#
# See more: https://en.wikipedia.org/wiki/Priority_search_tree
#
# It is possible to build such a tree in place, given an array of pairs. See De, Maheshwari, Nandy, Smid, _An in-place priority
# search tree_, 23rd Annual Canadian Conference on Computational Geometry.
#
# But I don't really understand the algorithm from the description. So I'm coding it up so I can see what is going on.
#
# For a while I started implementing the Min-max Priority Search Tree (see that file) but got very confused by the Highest3Sided
# algorithm. So for now I'm coming back here to see if I can work out the version for this (simpler) data structure.
#
# Since there is an alternate data structure that is a "min-max priority search tree" we call this one a "max priority search tree"
# or MaxPST.

Pair = Struct.new(:x, :y)

class MaxPrioritySearchTree
  INFINITY = Float::INFINITY

  # The array of pairs is turned into a PST in-place without cloning. So clone before passing it in, if you care.
  #
  # Each element must respond to #x and #y. Use Pair (above) if you like.
  def initialize(data, verify: false)
    @data = data
    @size = @data.size

    construct_pst
    return unless verify

    puts "Validating tree structure..."
    verify_properties
  end

  ########################################
  # Highest NE

  # A small scope in which to put helper code for the highest_ne algorithm. EXPERIMENTAL.
  #
  # This idea, if it is feasible, may help break up long methods like highest_3_sided that have more complicated helper functions.
  #
  # From the paper:
  #
  #   The algorithm uses two variables best and p, which satisfy the following invariant
  #
  #     - If Q intersect P is nonempty then p* in {best} union T_p
  #     - If Q intersect P is empty then p* = best
  #
  # Here, P is the set of points in our data structure and T_p is the subtree rooted at p
  class HighestNEHelper
    attr_accessor :p
    attr_reader :best

    def initialize(initial_p, x0, y0, pst)
      @p = initial_p
      @best = Pair.new(INFINITY, -INFINITY)
      @pst = pst # only for val_at
      @x0 = x0
      @y0 = y0
    end

    # From the paper:
    #
    #   takes as input a point t and does the following: if t \in Q and y(t) > y(best) then it assignes best = t
    #
    # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
    def update_highest(node)
      t = @pst.send(:val_at, node)
      if in_q(t) && t.y > @best.y
        @best = t
      end
    end

    def in_q(pair)
      pair.x >= @x0 && pair.y >= @y0
    end
  end

  # Find the "highest" (max-y) point that is "northeast" of (x, y).
  #
  # That is, the point p* in Q = [x, infty) X [y, infty) with the largest y value, or (infty, -infty) if there is no point in that
  # quadrant.
  #
  # Algorithm is from De et al. section 3.1
  def highest_ne(x0, y0)
    helper = HighestNEHelper.new(root, x0, y0, self)

    # We could make this code more efficient. But since we only have O(log n) steps we won't actually gain much so let's keep it
    # readable and close to the paper's pseudocode for now.
    until leaf?(helper.p)
      p_val = val_at(helper.p)
      if helper.in_q(p_val)
        # p \in Q and nothing in its subtree can beat it because of the max-heap
        helper.update_highest(helper.p)
        return helper.best

        # p = left(p) <- from paper
      elsif p_val.y < y0
        # p is too low for Q, so the entire subtree is too low as well
        return helper.best

        # p = left(p)
      elsif one_child?(helper.p)
        # With just one child we need to check it
        helper.p = left(helper.p)
      elsif val_at(right(helper.p)).x <= x0
        # right(p) might be in Q, but nothing in the left subtree can be, by the PST property on x.
        helper.p = right(helper.p)
      elsif val_at(left(helper.p)).x >= x0
        # Both children are in Q, so try the higher of them. Note that nothing in either subtree will beat this one.
        higher = left(helper.p)
        if val_at(right(helper.p)).y > val_at(left(helper.p)).y
          higher = right(helper.p)
        end
        helper.p = higher
      elsif val_at(right(helper.p)).y < y0
        # Nothing in the right subtree is in Q, but maybe we'll find something in the left
        helper.p = left(helper.p)
      else
        # At this point we know that right(p) \in Q so we need to check it. Nothing in its subtree can beat it so we don't need to
        # look there. But there might be something better in the left subtree.
        helper.update_highest(right(helper.p))
        helper.p = left(helper.p)
      end
    end
    helper.update_highest(helper.p) # try the leaf
    helper.best
  end

  ########################################
  # Leftmost NE

  # Let Q = [x0, infty) X [y0, infty) be the northeast "quadrant" defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (infty, infty) f Q \intersect P is empty and
  # - the leftmost (min-x) point in Q \intersect P otherwise
  #
  # This method returns p*.
  #
  # From De et al:
  #
  #   The algorithm uses three variables best, p, and q which satisfy the folling invariant:
  #
  #     - if Q \intersect P is empty then p* = best
  #     - if Q \intersect P is nonempty then  p* \in {best} \union T(p) \union T(q)
  #     - p and q are at the same level of T and x(p) <= x(q)
  def leftmost_ne(x0, y0)
    best = Pair.new(INFINITY, INFINITY)
    p = q = root

    in_q = lambda do |pair|
      pair.x >= x0 && pair.y >= y0
    end

    # From the paper:
    #
    #   takes as input a point t and does the following: if t \in Q and x(t) < x(best) then it assignes best = t
    #
    # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
    update_leftmost = lambda do |node|
      t = val_at(node)
      if in_q.call(t) && t.x < best.x
        best = t
      end
    end

    until leaf?(p)
      update_leftmost.call(p)
      update_leftmost.call(q)

      # SO many cases!
      #
      # We can make this more efficient by storing values accessed more than once. But we only run the loop lg(N) times so gains
      # would be limited. Leave the code easier to read and close to the paper's pseudocode unless we have reason to change it.
      #
      # ...actually, the code asthetics bothered me, so I have included a little bit of value caching. But I've left the nesting of
      # the logic to match the paper's code.
      if p == q
        if one_child?(p)
          p = q = left(p)
        else
          q = right(p)
          p = left(p)
        end
      else
        # p != q
        if leaf?(q)
          q = p # p itself is just one layer above the leaves, or is itself a leave
        elsif one_child?(q)
          q_left_val = val_at(left(q))
          if q_left_val.y < y0
            q = right(p)
            p = left(p)
          elsif (p_right_val = val_at(right(p))).y < y0
            p = left(p)
            q = left(q)
          elsif q_left_val.x < x0
            p = q = left(q)
          elsif p_right_val.x < x0
            p = right(p)
            q = left(q)
          else
            q = right(p)
            p = left(p)
          end
        else
          # q has two children
          p_right_val = val_at(right(p))
          if in_q.call(p_right_val)
            q = right(p)
            p = left(p)
          elsif p_right_val.x < x0
            q_left_val = val_at(left(q))
            if q_left_val.x < x0
              p = left(q)
              q = right(q)
            elsif q_left_val.y < y0
              p = right(p)
              q = right(q)
            else
              p = right(p)
              q = left(q)
            end
          else
            # x(p_r) >= x0 and y(p_r) < y0
            if val_at(left(p)).y < y0
              p = left(q)
              q = right(q)
            else
              p = left(p)
              if val_at(left(q)).y >= y0
                q = left(q)
              else
                q = right(q)
              end
            end
          end
        end
      end
    end
    update_leftmost.call(p)
    update_leftmost.call(q)
    best
  end

  ########################################
  # Highest 3 Sided

  # From the paper:
  #
  #    The three real numbers x0, x1, and y0 define the three-sided range Q = [x0,x1] X [y0,∞). If Q \intersect P̸ is not \empty,
  #    define p* to be the highest point of P in Q. If Q \intersect P = \empty, define p∗ to be the point (infty, -infty).
  #    Algorithm Highest3Sided(x0,x1,y0) returns the point p∗.
  #
  #    The algorithm uses two bits L and R, and three variables best, p, and q. As before, best stores the highest point in Q found
  #    so far. The bit L indicates whether or not p∗ may be in the subtree of p; if L=1, then p is to the left of Q. Similarly, the
  #    bit R indicates whether or not p∗ may be in the subtree of q; if R=1, then q is to the right of Q.
  #
  # Although there are a lot of lines and cases the overall idea is simple. We maintain in p the rightmost node at its level that is
  # to the left of the area Q. Likewise, q is the leftmost node that is the right of Q. The logic just updated this data at each
  # step. The helper check_left updates p and check_right updates q.
  #
  # A couple of simple observations that show why maintaining just these two points is enough.
  #
  # - We know that x(p) < x0. This tells us nothing about the x values in the sutrees of p (which is why we need to check various
  #   cases), it doess tell us that everything to the left of p has values of x that are too small to bother with.
  # - We don't need to maintain any state inside the region Q because the max-heap property means that if we ever find a node r in Q
  #   we check it for best and then ignore its subtree (which cannot beat r on y-value).
  #
  # Sometimes we don't have a relevant node to the left or right of Q. The booleans L and R (which we call left and right) track
  # whether p and q are defined at the moment.
  def highest_3_sided(x0, x1, y0)
    best = Pair.new(INFINITY, -INFINITY)
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
      t = val_at(node)
      if in_q.call(t) && t.y > best.y
        best = t
      end
    end

    # "Input: a node p such that x(p) < x0""
    #
    # TODO: understand what is going on here so I can implement check_right
    #
    # Step-by-step it is pretty straightforward. As the paper says
    #
    #   [E]ither p moves one level down thin the tree T or the bit L is set to 0. In addition, the point q either stays the same or
    #   it become a child of (the original) p.
    check_left = lambda do
      if leaf?(p)
        left = false # Question: did p ever get checked as a potential winner?
      elsif one_child?(p)
        if x_range.cover? val_at(left(p)).x
          update_highest.call(left(p))
          left = false # can't do y-better in the subtree
        elsif val_at(left(p)).x < x0
          p = left(p)
        else
          q = left(p)
          right = true
          left = false
        end
      else
        # p has two children
        if val_at(left(p)).x < x0
          if val_at(right(p)).x < x0
            p = right(p)
          elsif val_at(right(p)).x <= x1
            update_highest.call(right(p))
            p = left(p)
          else
            # x(p_r) > x1, so q needs to take it
            q = right(p)
            p = left(p)
            right = true
          end
        elsif val_at(left(p)).x <= x1
          update_highest.call(left(p))
          left = false # we won't do better in T(p_l)
          if val_at(right(p)).x > x1
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
      elsif one_child?(q)
        if x_range.cover? val_at(left(q)).x
          update_highest.call(left(q))
          right = false # can't do y-better in the subtree
        elsif val_at(left(q)).x < x0
          p = left(q)
          left = true
          right = false
        else
          q = left(q)
        end
      else
        # q has two children
        if val_at(left(q)).x < x0
          left = true
          if val_at(right(q)).x < x0
            p = right(q)
            right = false
          elsif val_at(right(q)).x <= x1
            update_highest.call(right(q))
            p = left(q)
            right = false
          else
            # x(q_r) > x1
            p = left(q)
            q = right(q)
            # left = true
          end
        elsif val_at(left(q)).x <= x1
          update_highest.call(left(q))
          if val_at(right(q)).x > x1
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

    root_val = val_at(root)

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

  # From the paper
  #
  #  "Given three real numbers x0, x1, and y0 define the three sided range Q = [x0, x1] X [y0, infty). Algorithm Enumerage3Sided(x0,
  #   x1,y0) returns all elements of Q \intersect P. The algorithm uses the same approach as algorithm Highest3Sided. Besides the
  #   two bits L and R it uses two additional bits L' and R'. Each of these four bits ... corresponds to a subtree of T rooted at
  #   the points p, p', q, and q', respectively; if the bit is equal to one, then the subtree may contain points that are in the
  #   query range Q.
  #
  #   The following variant will be maintained:
  #
  #   - If L = 1 then x(p) < x0.
  #   - If L' = 1 then x0 <= x(p') <= x1.
  #   - If R = 1 then x(q) > x1.
  #   - If R' = 1 then x0 <= x(q') <= x1.
  #   - If L' = 1 and R' = 1 then x(p') <= x(q').
  #   - All points in Q \intersect P [other than those in the subtrees of the currently active search nodes] have been reported.""

  def enumerate_3_sided(x0, x1, y0)
    x_range = x0..x1
    # Instead of using primes we use "_in"
    left = left_in = right_in = right = false
    p = p_in = q_in = q = nil


    result = []

    # Note: for now just accumulate the values in an array and return it.
    report = ->(node) { result << val_at(node) }

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
          # Isn't this pre-order?
          if val_at(current).y >= y0
            report.call(current)
          end
          if !leaf?(current) && val_at(left(current)).y >= y0
            current = left(current)
          else
            state = 1
          end
        when 1
          # State 1: we've already handled this node and its left subtree. Should we descend to the right subtree?
          if two_children?(current) && val_at(right(current)).y >= y0
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
          raise "Explore(t) state is somehow #{state} rather than 0, 1, or 2."
        end
      end
    end

    # Handle the next step of the subtree at p
    #
    # I need to go through this with paper, pencil, and some diagrams.
    enumerate_left = lambda do
      if leaf(p)
        left = false
      elsif one_child?(p)
        if x_range.cover? val_at(left(p)).x
          if left_in && right_in
            # Idea: because x(q_in) <= x1, p_in and its subtree are squeezed inside [x0, x1] by p and q_in. Thus we can exhaust p_in
            # and its subtree merely by looking and the y-values.
            explore.call(p_in)
          elsif left_in
            q_in = p_in
            right_in = true
          end
          p_in = left(p)
          left_in = true
          left = false
        elsif val_in(left(p)) < x0
          p = left(p)
        else
          q = left(p)
          right = true
          left = false
        end
      else
        # p has two children
        if val_at(left(p)).x < x0
          if val_at(right(p)).x < x0
            p = right(p)
          elsif val_at(right(p)).x <= x1
            if left_in && right_in
              # right(p) is inside [x0, x1] and so it at q_in squeeze all of p_in inside that interval too.
              explore.call(p_in)
            elsif left_in
              q_in = p_in
              right_in = true
            end
            p_in = right(p)
            p = left(p)
            left_in = true
          else
            q = right(p)
            p = left(p)
            right = true
          end
        elsif val_at(left(p)).x <= x1
          if val_at(right(p)) > x1
            q = right(p)
            p_in = left(p)
            left = false
            left_in = right_in = true
          else
            # p_l lies inside [x0, x1], so if also q_in is active, p_r and p_in and both squeezed in [x0, x1]
            if left_in && right_in
              explore(p_in)
              explore(right(p))
            elsif left_in
              # p_in squeezes right(p) inside [x0, x1]
              explore(right(p))
              q_in = p_in
              right_in = true
            elsif right_in
              # Now q_in squeezes right(p) inside [x0, x1]
              explore(right(p))
              left_in = true
            else
              q_in = right(p)
              left_in = right_in = true
            end
            p_in = left(p)
            left = false
          end
        else
          q = left(p)
          left = false
          right = true
        end
      end
    end

    val = ->(sym) { { left: p, left_in: p_in, right_in: q_in, right: q }[sym] }

    root_val = val_at(root)
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
        raise "bad symbol #{z}"
      end
    end
    result
  end

  ########################################
  # Build the initial stucture

  private def construct_pst
    # We follow the algorithm in the paper by De, Maheshwari et al. Note that indexing is from 1 there. For now we pretend that that
    # is the case here, too.
    h = Math.log2(@size).floor
    a = @size - (2**h - 1) # the paper calls it A
    sort_subarray(1, @size)

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

  ########################################
  # Indexing the data structure as though it were from 1, even though the underlying @data is indexed from zero.

  # First element and root of the tree structure
  private def root
    1
  end

  private def val_at(idx)
    @data[idx - 1]
  end

  # Indexing is from 1
  private def parent(i)
    i >> 1
  end

  private def left(i)
    i << 1
  end

  private def right(i)
    1 + (i << 1)
  end

  private def level(i)
    l = 0
    while i > root
      i >>= 1
      l += 1
    end
    l
  end

  # i has no children
  private def leaf?(i)
    left(i) > @size
  end

  # i has exactly one child (the left)
  private def one_child?(i)
    left(i) <= @size && right(i) > @size
  end

  # i has two children
  private def two_children?(i)
    right(i) <= @size
  end

  # i is the left child of its parent.
  private def left_child?(i)
    i > 1 && (i % 2).zero?
  end

  private def swap(index1, index2)
    return if index1 == index2

    @data[index1 - 1], @data[index2 - 1] = @data[index2 - 1], @data[index1 - 1]
  end

  # The index in @data[l..r] having the largest value for y
  private def index_with_largest_y_in(l, r)
    return nil if r < l

    (l..r).max_by { |idx| val_at(idx).y }
  end

  # Sort the subarray @data[l..r]. This is much faster than a Ruby-layer heapsort because it is mostly happening in C.
  private def sort_subarray(l, r)
    # heapsort_subarray(l, r)
    return if l == r # 1-array already sorted!

    l -= 1
    r -= 1
    @data[l..r] = @data[l..r].sort_by(&:x)
  end

  ########################################
  # Debugging support
  #
  # These methods are not written for speed

  # Check that our data satisfies the requirements of a Priority Search Tree:
  # - max-heap in y
  # - all the x values in the left subtree are less than all the x values in the right subtree
  def verify_properties
    # It's a max-heap in y
    (2..@size).each do |node|
      raise "Heap property violated at child #{node}" unless val_at(node).y < val_at(parent(node)).y
    end

    # Left subtree has x values less than all of the right subtree
    (1..@size).each do |node|
      next if right(node) >= @size

      left_max = max_x_in_subtree(left(node))
      right_min = min_x_in_subtree(right(node))

      raise "Left-right property of x-values violated at #{node}" unless left_max < right_min
    end
  end

  private def max_x_in_subtree(root)
    return -Float::INFINITY if root >= @size

    [val_at(root).x, max_x_in_subtree(left(root)), max_x_in_subtree(right(root))].max
  end

  private def min_x_in_subtree(root)
    return Float::INFINITY if root >= @size

    [val_at(root).x, min_x_in_subtree(left(root)), min_x_in_subtree(right(root))].min
  end
end
