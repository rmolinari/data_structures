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

Pair = Struct.new(:x, :y)

class PrioritySearchTree
  # The array of pairs is turned into a PST in-place without cloning. So clone before passing it in, if you care.
  #
  # Each element must respond to #x and #y. Use Pair (above) if you like.
  def initialize(data)
    @data = data
    @size = @data.size

    constructPST

    # puts "Validating tree structure..."
    # verify_properties
  end

  private def constructPST
    # We follow the algorithm in the paper by De, Maheshwari et al. Note that indexing is from 1 there. For now we pretend that that
    # is the case here, too.
    h = Math.log2(@size).floor
    a = @size - (2**h - 1) # the paper calls it A
    sort_subarray(1, @size)
    # byebug

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

  private def val_at(idx)
    @data[idx - 1]
  end

  private def root
    0
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
