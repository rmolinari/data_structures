# A priority search tree (PST) stores points in two dimensions (x,y) and can efficiently answer certain questions about the set of
# point.
#
# The structure was introduced by McCreight [1].
#
# It is a binary search tree which is a max-heap by the y-coordinate, and, for a non-leaf node N storing (x, y), all the nodes in
# the left subtree of N have smaller x values than any of the nodes in the right subtree of N. Note, though, that the x-value at N
# has no particular property relative to the x values in its subtree. It is thus _almost_ a binary search tree in the x coordinate.
#
# See more: https://en.wikipedia.org/wiki/Priority_search_tree
#
# It is possible to build such a tree in place, given an array of pairs. See [2]. In a follow-up paper, [3], the authors show how to
# construct a more flexible data structure,
#
#   "[T]he Min-Max Priority Search tree for a set P of n points in R^2. It is a binary tree T with the following properties:
#
#    * For each internal node u, all points in the left subtree of u have an x-coordinate which is less than the x-coordinate of any
#      point in the right subtree of u.
#    * The y-coordinate values of the nodes on even (resp. odd) levels are smaller (resp. greater) than the y-coordinate values of
#      their descendants (if any), where the root is at level zero.
#
#    "The first property implies that T is a binary search three on the x-coordinates of the points in P, excepts that there is no
#     relation between the x-coordinates of the points stored at u and any of its children. The second property implies that T is a
#     min-max heap on the y-coordinates of the points in P."
#
# I started implementing the in-place PST. Then, finding the follow-up paper [3], decided to do that one instead, as the paper says
# it is more flexible. The point is to learn a new data structure and its associated algorithms.
#
# Hmmm. The algorithms are rather bewildering. Highest3SidedUp is complicated, and only two of the functions CheckLeft, CheckLeftIn,
# CheckRight, CheckRightIn are given; the other two are "symmetric". But it's not really clear what the first are actually doing, so
# it's hard to know what the others actually do.
#
# I either need to go back to MaxPST until I understand things better, or spend quite a lot of time going through the algorithms
# here on paper.

# [1] E. McCreight, _Priority Search Trees_, SIAM J. Computing, v14, no 3, May 1985, pp 257-276.
# [2] De, Maheshwari, Nandy, Smid, _An in-place priority search tree_, 23rd Annual Canadian Conference on Computational Geometry.
# [3] De, Maheshwari, Nandy, Smid, _An in-place min-max priority search tree_, Computational Geometry, v46 (2013), pp 310-327.
# [4] Atkinson, Sack, Santoro, Strothotte, _Min-max heaps and generalized priority queues_, Commun. ACM 29 (10) (1986), pp 996-1000.

require 'must_be'

Pair = Struct.new(:x, :y) do
  def fmt
    "(#{x},#{y})"
  end
end

class MinmaxPrioritySearchTree
  INFINITY = Float::INFINITY

  # The array of pairs is turned into a minmax PST in-place without cloning. So clone before passing it in, if you care.
  #
  # Each element must respond to #x and #y. Use Pair (above) if you like.
  def initialize(data, verify: false)
    @data = data
    @size = @data.size

    construct_pst
    return unless verify

    # puts "Validating tree structure..."
    verify_properties
  end

  # Let Q = [x0, infty) X [y0, infty) be the northeast "quadrant" defined by the point (x0, y0) and let P be the points in this data
  # structure. Define p* as
  #
  # - (infty, infty) if Q \intersect P is empty and
  # - the leftmost (i.e., min-x) point in Q \intersect P otherwise
  #
  # This method returns p*.
  #
  # From De et al:
  #
  #   [t]he variables best, p, and q satisfy the folling invariant:
  #
  #     - if Q \intersect P is nonempty then  p* \in {best} \union T(p) \union T(q)
  #     - if Q \intersect P is empty then p* = best
  #     - p and q are at the same level of T and x(p) <= x(q)
  #
  # Here T(x) is the subtree rooted at x
  def leftmost_ne(x0, y0)
    best = Pair.new(INFINITY, INFINITY)
    p = q = root

    in_q = ->(pair) { pair.x >= x0 && pair.y >= y0 }

    # From the paper:
    #
    #   takes as input a point t \in P and updates best as follows: if t \in Q and x(t) < x(best) then it assignes best = t
    #
    # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
    update_leftmost = lambda do |node|
      t = val_at(node)
      if in_q.call(t) && t.x < best.x
        best = t
      end
    end

    # Generalize the c1,...,c4 idea from the paper in line with the BUG 2 IN PAPER notes, below.
    #
    # Given: 0 or more nodes n1, ..., nk in the tree. All are at the same level, which is a "max level" in our MinmaxPST, such that
    # x(n1) <= x(n2) <= ... <= x(nk). (Note: it is expected that the nj are either children or grandchildren of p and q, though we
    # don't check that.)
    #
    # If k = 0 return nil. Otherwise...
    #
    # We return two values p_goal, q_goal (possibly equal) from among the nj such that
    #
    #    - p_goal is not to the right of q_goal in the tree and so, in particular x(p_goal) <= x(q_goal)
    #    - if and when the auction reaches p = p_goal and q = q_goal the algorithm invariant will be satisfied.
    #
    # As a special case, we return nil if we detect that none of the subtrees T(nj) contain any points in Q. This is a sign to
    # terminate the algorithm.
    #
    # See the notes at "BUG 2 IN PAPER" below for more details about what is going on.
    determine_goal_nodes = lambda do |nodes|
      node_count = nodes.size
      return nil if node_count.zero?

      if val_at(nodes.last).x <= x0
        # Only the rightmost subtree can possibly have anything Q, assuming that all the x-values are distinct.
        return [nodes.last, nodes.last]
      end

      if val_at(nodes.first).x > x0
        # All subtrees have x-values large enough to provide elements of Q. Since we are at a max-level the y-values help us work
        # out which subtree to focus on.
        leftmost = nodes.find { |node| val_at(node).y >= y0 }

        return nil unless leftmost # nothing left to find

        # Otherwise we explore the leftmost subtree. Its root is in Q and can't be beaten by anything to its right.
        return [leftmost, leftmost]
      end

      values = nodes.map { |n| val_at(n) }

      # Otherwise x(n1) <= x0 < x(nk). Thus i is well-defined.
      i = (0...node_count).select { |j| values[j].x <= x0 && x0 < values[j + 1].x }.min

      # these nodes all have large-enough x-values and so this finds the ones in the set Q.
      new_q = nodes[(i + 1)..].select { |node| val_at(node).y >= y0 }.min # could be nil
      new_p = nodes[i] if values[i].y >= y0 # The leftmost subtree is worth exploring if the y-value is big enough. Otherwise not
      new_p ||= new_q # if nodes[i] is no good we send p along with q
      new_q ||= new_p # but if there was no worthwhile value for q we should send it along with p

      return nil unless new_p

      [new_p, new_q]
    end

    until leaf?(p)
      level = Math.log2(p).floor # TODO: don't calculate log every time!

      update_leftmost.call(p)
      update_leftmost.call(q)

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
          q = p # p itself is just one layer above the leaves, or is itself a leaf
        elsif one_child?(q)
          # Note that p has two children
          if val_at(left(q)).x < x0
            # x-values below p are too small
            p = q = left(q)
          elsif val_at(right(p)).x <= x0
            # x-values in T(right(p)) are too small. DISTINCT-X
            p = right(p)
            q = left(q)
          else
            # BUG 1 IN PAPER.
            #
            # So, x(q_l) >= x0 and x(p_r) > x0. But how can we be sure that the child of q isn't the winner?. Should we be trying
            # it in this case?
            #
            # Yes: otherwise it never gets checked.

            update_leftmost.call(left(q))
            q = right(p)
            p = left(p)
          end
        else
          # p and q both have two children

          # BUG 2 IN PAPER.
          #
          # Define c as the paper does:
          #
          #   (c1, c2, c3, c4) = (left(p), right(p), left(q), right(q))
          #
          # Because of the PST property on x and the invariant x(p) <= x(q) we know that
          #
          #   x(c1) <= x(c2) <= x(c3) <= x(c4)
          #
          # Similarly, the sets of values x(T(ci)) are pairwise ordered in the same sense.
          #
          # Suppose further that x(ci) <= x0 <= x(c(i+i)). Then we know several things
          #
          #   - there might be a "winner" (point in Q) in T(ci), perhaps ci itself.
          #   - there are not any winners in T(cj) for j < i, becasue the x-values there aren't big enough
          #   - any winner in ck, for k >= i, will be the left of and thus beat any winner in c(k+1), because of the ordering of
          #     x-values
          #
          # If x(c4) <= x0 then the rightmost subtree T(c4) is the only one worth checking and we set p = q = c4.
          # If x(c1) > x0 then we take i = 0 and ignore the logic on ci in what follows and setting p = q.
          #
          # Pretend for the moment that we are using a MaxPST instead of a MinmaxPST. Then we can look at y values to learn more.
          #
          #   - if y(ci) >= y0 then we need to search T(ci), so we will update p = ci
          #   - but if y(ci) < y0 then there are no winners in T(ci) because the y-values are too small.
          #   - similarly, if y(c(i+i)) >= y0 then we need to search T(c(i+1)). Indeed c(i+1) itself is in Q and beats any winner in
          #     subtrees further to the right
          #   - so, let k > i be minimal such that y(ck) >= y0, if there is any. Note that ck is itself a winner. Then
          #     - if y(ci) >= y0,
          #       - set p = ci, and q = ck (or q = ci if there is no such k)
          #     - otherwise (T(ci) has no winners because its y-values are too small)
          #       - if k is defined set p = q = ck. Otherwise HALT (there are no more winners)
          #
          # But we are working with a MinmaxPST rather than a MaxPST, so we have to work harder. If c1, ..., c4 (the children of p
          # and q) are in a "max-level" of the tree - that is, an even level - then the logic above still applies. But if they are
          # at a min level things are trickier and we need to go another layer down.
          #
          # The paper knows that we need to look a further layer down, but the logic is too simplistic. It looks at cj for j > i and
          # checks if cj or either of its children are in Q. But that's not good enough. For the same reason that in a MaxPST we may
          # need to explore below T(ci) even if ci isn't in Q, we may need to decend through one of the grandchilden of p or q even
          # if that grandchild isn't in Q.
          #
          # Getting a bit handwavey especially over what happens near the leaves...
          #
          # Consider the children d1, d2, ..., dm, of ci, ..., c4 (and so grandchildren of p and q). They are at a max-level and so
          # the logic described applies to the dk. If ci happens to be a winner we can set p = ci and work out what to do with q by
          # looking at the children of c(i+1), ..., c4. Otherwise we look at all the dj values (up to 8 of them), apply the logic
          # above to work out that we want to head for, say, p = ds and q = dt, and in this cycle update p = parent(ds), q =
          # parent(dt).  (We also need to submit the values c(i+1)..c4 to UpdateLeftmost.)
          #
          # In other words, we can use the MaxPST logic on d1,...,dm to decide where we need to go, and then step to the relevant
          # parents among the cj.

          c = [left(p), right(p), left(q), right(q)]
          if level.odd?
            # the elements of c are at an even level, and hence their y values are maxima for the subtrees. We can learn what we
            # need to know from them
            p, q = determine_goal_nodes.call(c)
            if p && !q
              # byebug
              # determine_goal_nodes.call(c)
              raise 'bad logic'
            end
          else
            # They are at an odd level and so aren't helpful in working out what to do next: we look at their children, which are in
            # a max-level. We need to check the elements of c against best since we are otherwise ignoring them.
            c.each { |n| update_leftmost.call(n) }

            d = c.map { [left(_1), right(_1)]}.flatten.select { |n| n <= @size }

            # Note that we are jumping down two levels here!
            p, q = determine_goal_nodes.call(d)
            if p && !q
              # byebug
              # determine_goal_nodes.call(c)
              raise 'bad logic'
            end

            p
          end

          return best unless p # nothing more to do
        end
      end
    end
    update_leftmost.call(p)
    update_leftmost.call(q)
    best
  end

  # Let Q be the "three-sided query range" [x0, x1] X [y0, infty) and let P_Q be P \intersect Q.
  #
  # If P_Q is empty then p* = (infty, -infty).
  # Otherwise, p* is the point in P_Q with maximal y value.
  #
  # This method returns p*
  # def highest_3_sided_up(x0, x1, y0)
  #   best = Pair.new(INFINITY, -INFINITY)

  #   in_q = lambda do |pair|
  #     pair.x >= x0 && pair.x <= x1 && pair.y >= y0
  #   end

  #   # From the paper:
  #   #
  #   #   takes as input a point t and does the following: if t \in Q and y(t) > y(best) then it assignes best = t
  #   #
  #   # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
  #   #
  #   # The algorithm is complicated. From the paper:
  #   #
  #   #   Since Q is bounded by two vertical sides, we use four index variables p, p', q and q' to guide the search path. In addition,
  #   #   we use four bits L, L', R and R'; these correspond to the subtrees of T rooted at the nodes p, p', q, and q', respectively;
  #   #   if a bit is equal to one, then the corresonding node is referred to as an _active node_ (for example, if L = 1 then p is an
  #   #   active node), and the subtree rooted at that node may contain a candidate point for p*. So the search is required to be
  #   #   performed in the subtree rooted at all active nodes. More formally, at any instant of time the variables satisfy the folling
  #   #   invariants:
  #   #
  #   #     - If L  = 1 the x(p) < x0.
  #   #     - If L' = 1 then x0 <= x(p') <= x1.
  #   #     - If R  = 1 then x(q) > x1.
  #   #     - If R' = 1 then x0 <= x(q') <= x1.
  #   #     - If L' = 1 and R' = 1 then x(p') <= x(q').
  #   #     - If P_Q is non-empty then p* = best or p* is in the subtree rooted at any one of the active nodes.
  #   #
  #   # There are more details in the paper
  #   update_highest = lambda do |node|
  #     t = val_at(node)
  #     if in_q.call(t) && t.y > best.y
  #       best = t
  #     end
  #   end

  #   ex_update_highest = lambda do |node|
  #     update_highest.call(node)
  #     update_highest.call(left(node)) unless leaf?(node)
  #     update_highest.call(right(node)) unless one_child?(node)
  #   end

  #   if val_at(root).x < x0
  #     p = root
  #     l = true
  #     l_prime = r = r_prime = false
  #   elsif val_at(root).x < x1
  #     p_prime = root
  #     l_prime = true
  #     l = r = r_prime = false
  #   else
  #     q = root
  #     r = true
  #     l = l_prime = r_prime = false
  #   end

  #   set_z = lambda do
  #     r = []
  #     r << p if l
  #     r << p_prime if l_prime
  #     r << q if r
  #     r << q_prime if r_primg
  #     r
  #   end

  #   check_left = lambda do
  #     if leaf?(p)
  #       l = false
  #     elsif one_child?(p)
  #       p_l_x = val_at(left(p))
  #       if x0 <= p_l_x && p_l_x <= x1
  #         update_highest.call(left(p))
  #         if l_prime && r_prime
  #           ex_update_highest.call(p_prime)
  #         elsif l_prime
  #           q_prime = p_prime
  #           r_prime = true
  #         end
  #         p_prime = left(p)
  #         l_prime = true
  #         l = false
  #       elsif p_l_x < x0
  #         p = left(p)
  #       else
  #         q = left(p)
  #         r = true
  #         l = false
  #       end
  #     else
  #       # p has two children

  #   end

  #   while l || l_prime || r || r_prime
  #     z_star = set_z.call.min_by(4) { level(_1) }
  #     if z_star.include? p_prime
  #       check_left_in(p_prime)
  #     elsif z_star.include? q_prime
  #       check_right_in(q_prime)
  #     elsif z_star.include? p
  #       check_left(p)
  #     else
  #       check_right(q)
  #     end
  #   end
  # end

  # Find the "highest" (max-y) point that is "northeast" of (x, y).
  #
  # That is, the point p* in Q = [x, infty) X [y, infty) with the largest y value, or (infty, -infty) if there is no point in that
  # quadrant.
  #
  # Algorithm is from De et al. section 3.1
  def highest_ne(x0, y0)
    raise "Write me"
    # From the paper:
    #
    #   The algorithm uses two variables best and p, which satisfy the following invariant
    #
    #     - If Q intersect P is nonempty then p* in {best} union T_p
    #     - If Q intersect P is empty then p* = best
    #
    # Here, P is the set of points in our data structure and T_p is the subtree rooted at p
    best = Pair.new(INFINITY, -INFINITY)
    p = root # root of the whole tree AND the pair stored there

    in_q = lambda do |pair|
      pair.x >= x0 && pair.y >= y0
    end

    # From the paper:
    #
    #   takes as input a point t and does the following: if t \in Q and y(t) > y(best) then it assignes best = t
    #
    # Note that the paper identifies a node in the tree with its value. We need to grab the correct node.
    update_highest = lambda do |node|
      t = val_at(node)
      if in_q.call(t) && t.y > best.y
        best = t
      end
    end

    # We could make this code more efficient. But since we only have O(log n) steps we won't actually gain much so let's keep it
    # readable and close to the paper's pseudocode for now.
    until leaf?(p)
      p_val = val_at(p)
      if in_q.call(p_val)
        # p \in Q and nothing in its subtree can beat it because of the max-heap
        update_highest.call(p)
        return best

        # p = left(p) <- from paper
      elsif p_val.y < y0
        # p is too low for Q, so the entire subtree is too low as well
        return best

        # p = left(p)
      elsif one_child?(p)
        # With just one child we need to check it
        p = left(p)
      elsif val_at(right(p)).x <= x0
        # right(p) might be in Q, but nothing in the left subtree can be, by the PST property on x.
        p = right(p)
      elsif val_at(left(p)).x >= x0
        # Both children are in Q, so try the higher of them. Note that nothing in either subtree will beat this one.
        higher = left(p)
        if val_at(right(p)).y > val_at(left(p)).y
          higher = right(p)
        end
        p = higher
      elsif val_at(right(p)).y < y0
        # Nothing in the right subtree is in Q, but maybe we'll find something in the left
        p = left(p)
      else
        # At this point we know that right(p) \in Q so we need to check it. Nothing in its subtree can beat it so we don't need to
        # look there. But there might be something better in the left subtree.
        update_highest.call(right(p))
        p = left(p)
      end
    end
    update_highest.call(p) # try the leaf
    best
  end

  # O(n log^2 n)
  private def construct_pst
    # We follow the algorithm in [3]. Indexing is from 1 there and we follow that here. The algorithm is almost exactly the same as
    # for the (max) PST.
    h = Math.log2(@size).floor
    a = @size - (2**h - 1) # the paper calls it A
    sort_subarray(1, @size)
    level = 0 # TODO: isn't level always equal to i in the loop?

    (0...h).each do |i|
      sense = level.even? ? :max : :min
      pow_of_2 = 2**i

      k = a / (2**(h - i))
      k1 = 2**(h + 1 - i) - 1
      k2 = (1 - k) * 2**(h - i) - 1 + a
      k3 = 2**(h - i) - 1
      (1..k).each do |j|
        l = index_with_extremal_y_in(pow_of_2 + (j - 1) * k1, pow_of_2 + j * k1 - 1, sense:)
        swap(l, pow_of_2 + j - 1)
      end

      if k < pow_of_2
        l = index_with_extremal_y_in(pow_of_2 + k * k1, pow_of_2 + k * k1 + k2 - 1, sense:)
        swap(l, pow_of_2 + k)

        m = pow_of_2 + k * k1 + k2
        (1..(pow_of_2 - k - 1)).each do |j|
          l = index_with_extremal_y_in(m + (j - 1) * k3, m + j * k3 - 1, sense:)
          swap(l, pow_of_2 + k + j)
        end
      end
      sort_subarray(2 * pow_of_2, @size)
      level += 1
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

  private def leaf?(i)
    left(i) > @size
  end

  private def one_child?(i)
    left(i) <= @size && right(i) > @size
  end

  private def swap(index1, index2)
    return if index1 == index2

    @data[index1 - 1], @data[index2 - 1] = @data[index2 - 1], @data[index1 - 1]
  end

  private def level(i)
    count = 0
    while i > root
      i >>= 1
      count += 1
    end
    count
  end

  # The index in @data[l..r] having the largest/smallest value for y
  # The sense argument should be :min or :max
  private def index_with_extremal_y_in(l, r, sense:)
    return nil if r < l

    case sense
    when :min
      (l..r).min_by { |idx| val_at(idx).y }
    when :max
      (l..r).max_by { |idx| val_at(idx).y }
    else
      raise "Bad comparison sense #{sense}"
    end
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
    # It's a min-max heap in y
    (2..@size).each do |node|
      level = Math.log2(node).floor
      parent_level = level - 1

      _, _, min_y, max_y = minmax_in_subtree(node)
      parent_y = val_at(parent(node)).y

      it_is_fine = if parent_level.even?
                     # max!
                     parent_y > max_y
                   else
                     parent_y < min_y
                   end

      raise "Heap property violated at child #{node}" unless it_is_fine
    end

    # Left subtree has x values less than all of the right subtree
    (1..@size).each do |node|
      next if right(node) >= @size

      left_max = max_x_in_subtree(left(node))
      right_min = min_x_in_subtree(right(node))

      raise "Left-right property of x-values violated at #{node}" unless left_max < right_min
    end

    nil
  end

  private def max_x_in_subtree(root)
    minmax_in_subtree(root)[1]
  end

  private def min_x_in_subtree(root)
    minmax_in_subtree(root)[0]
  end

  # Return min_x, max_x, min_y, max_y in subtree rooted at and including root
  private def minmax_in_subtree(root)
    @minmax_vals ||= []
    @minmax_vals[root] ||= calc_minmax_at(root).freeze
  end

  # No memoization
  private def calc_minmax_at(root)
    return [INFINITY, -INFINITY, INFINITY, -INFINITY] if root > @size

    pair = val_at(root)

    return [pair.x, pair.x, pair.y, pair.y] if leaf?(root)

    left = left(root)
    left_min_max = minmax_in_subtree(left)
    return left_min_max if one_child?(root)

    right = right(root)
    right_min_max = minmax_in_subtree(right)

    [
      [pair.x, left_min_max[0], right_min_max[0]].min,
      [pair.x, left_min_max[1], right_min_max[1]].max,
      [pair.y, left_min_max[2], right_min_max[2]].min,
      [pair.y, left_min_max[3], right_min_max[3]].max
    ]
  end

  private def output_quasi_dot
    (2..@size).to_a.reverse.map do |node|
      "#{val_at(parent(node)).fmt} -- #{val_at(node).fmt}"
    end.join("\n")
  end

  private def pair_to_s
  end

  ########################################
  # Dead code

end
