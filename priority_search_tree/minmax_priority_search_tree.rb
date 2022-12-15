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

# [1] E. McCreight, _Priority Search Trees_, SIAM J. Computing, v14, no 3, May 1985, pp 257-276.
# [2] De, Maheshwari, Nandy, Smid, _An in-place priority search tree_, 23rd Annual Canadian Conference on Computational Geometry.
# [3] De, Maheshwari, Nandy, Smid, _An in-place min-max priority search tree_, Computational Geometry, v46 (2013), pp 310-327.
# [4] Atkinson, Sack, Santoro, Strothotte, _Min-max heaps and generalized priority queues_, Commun. ACM 29 (10) (1986), pp 996-1000.

Pair = Struct.new(:x, :y)

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
    raise "Write me!"

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
    @minmax_vals[root] ||= calc_minmax_at(root)
  end

  # No memoization
  private def calc_minmax_at(root)
    return [INFINITY, -INFINITY, INFINITY, -INFINITY] if root >= @size

    pair = val_at(root)

    return [pair.x, pair.x, pair.y, pair.y] if leaf?(root)

    left = left(root)
    left_min_max = minmax_in_subtree(left)
    return left_min_max if one_child?(left)

    right = right(root)
    right_min_max = minmax_in_subtree(right)

    [
      [pair.x, left_min_max[0], right_min_max[0]].min,
      [pair.x, left_min_max[1], right_min_max[1]].max,
      [pair.y, left_min_max[2], right_min_max[2]].min,
      [pair.y, left_min_max[3], right_min_max[3]].max
    ]
  end

  ########################################
  # Dead code

  # Let's try implementing Knuth's heapsort algorithm 5.2.3-A
  #
  # This is much slower than the simple sort-the-slice approach, surely because
  #   1) it's written in Ruby, rather than C, and
  #   2) I use a bunch of lambdas, which we call zillions of times
  #
  # Let's not bother with this approach, as it's reasonable to assume that the Ruby framework has thought carefully about array
  # sorting and array-slice assignment.
  private def heapsort_subarray(left, right)
    return if right <= left # nothing to do

    # Knuth's algorithm sorts elements at indices 1, 2, ..., N. We will follow this, so let's use these helpers for now
    base_index_for = ->(idx) { idx + left - 1 } # idx 1 corresponds to left
    record_at = ->(idx) { val_at base_index_for.call(idx) }
    key_at = ->(idx) { record_at[idx].x }
    # another offset by 1 for the 0- vs 1-based. TODO: make this DRIER
    set_record_at = ->(idx, val) { @data[base_index_for[idx] - 1] = val }

    # Step H1 - Initialize
    size = (right - left + 1) # Knuth calls this N
    l = (size / 2) + 1
    r = size

    i = j = record = key = nil # scope
    state = :h2
    loop do
      # byebug
      case state
      when :h2
        # Step H2 - Decrease l or r

        # "If l > 1 we are in the process of transofrming the input file into a heap; on the other hand if l = 1, the Keys K1 K2
        # ... KN presently constitute a heap"
        if l > 1
          l -= 1
          record = record_at[l] # Knuth calls this R
          key = record.x # Knuth calls this K
        else
          record = record_at[r]
          key = record.x
          set_record_at.call(r, record_at[1])
          r -= 1

          if r == 1
            set_record_at.call(1, record)
            return
          end
        end
        state = :h3
      when :h3
        # "At this point we have
        #     K(k/2) >= K(k) for l < (k/2) < k <= r;
        # and record R(k) is in its final position for r < k < N. Steps H3-H8 are called the _siftup algorithm_; their effect is
        # equivalent to setting R(l) = R and then rearranging R(l),...R(r) so that [the inequality above] holds also for l = k/2""

        # Step H3 - Prepare for the siftup
        j = l
        state = :h4
      when :h4
        # Step H4 - Advance downwards
        i = j
        j *= 2
        # "In the following steps we have i = (j/2).floor"
        state = if j < r
                  :h5
                elsif j == r
                  :h6
                else
                  :h8
                end
      when :h5
        # Step H5 - Find larger child
        if key_at[j] < key_at[j + 1]
          j += 1
        end
        state = :h6
      when :h6
        # Step H6 - Larger than K?
        state = if key >= key_at[j]
                  :h8
                else
                  :h7
                end
      when :h7
        # Step H7 - Move it up
        set_record_at.call(i, record_at[j])
        state = :h4
      when :h8
        # Step H8 - Store R
        set_record_at.call(i, record) # "This terminates the siftup algirithm initiated in step H3"
        state = :h2
      else
        raise "Bad machine state #{state}"
      end
    end
  end
end
