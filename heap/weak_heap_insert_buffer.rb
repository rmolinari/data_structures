# An addressable heap that can be used for a priority queue.
#
# It implements the "weak heap" data structure described here:
#
#   Edelkamp, S., Elmasry, A., Katajainen, J., _The weak-heap data structure: Variants and applications_, Journal of Discrete
#   Algorithms, 2012, v16, pp 187-205.
#
# A weak heap relaxes the requirements for a heap. Each element is less than or equal to all the elements in its right subtree.
#
# We use an insert buffer with periodic bulk inserts to achieve O(1) amortized insertion.
#
# We provide
# - #empty?
#   - O(1)
# - #insert
#   - O(1) (amortized)
# - #top
#   - return the highest-priority element
#   - O(1)
# - #pop
#   - removes and returns the item with highest priority
#   - O(log N)
# - #update
#   - tell the heap that the priority of a particular item has changed
#   - O(log N)
#
class WeakHeapInsertBuffer
  # The root is at 0. Remember that the root node has no left subtree.
  ROOT = 0

  attr_reader :size

  Pair = Struct.new(:priority, :item)

  # Arguments:
  #
  # - max_heap: if truthy then implement a max-heap rather than the default min-heap
  # - addressable: if truthy then the heap supports #update
  # - debug: if truthy check the heap property after certain operations
  # - metrics: if truthy keep track of updates, inserts, pops, sift-ups, and sift-downs
  def initialize(max_heap: false, addressable: true, debug: false, metrics: false)
    @data = []
    @r = [] # the "reverse" or "flip" bits. Always 0 or 1

    @size = 0 # the size of the heap
    @main_size = 0 # the size of the fully-incorporated weak-heap structure
    @buffer_size = 2 # the size of the insertion buffer. This isn't necessarily the number of values actually in the insertion
                     # buffer.

    @min = nil        # the index of the minial element. It muight be in the insert buffer
    @buffer_min = nil # the index of the minimal element of the buffer. nil if the buffer is empty

    @max_heap = max_heap
    @debug = debug
    @metrics = Hash.new(0) if metrics
    @addressable = addressable
    @index_of = {} if @addressable
  end

  def empty?
    @size == 0
  end

  # To insert a value we first add it to the next availabe array entry making it a leaf. Then we call sift_up to restore the weak
  # heap property.
  def insert(value, priority)
    priority *= -1 if @max_heap
    d = Pair.new(priority, value)

    if @size == 0
      # always insert at root and don't mess with any buffer
      assign(d, ROOT)
      @r[ROOT] = 0
      @min = ROOT
      @size = 1
      @main_size = 1
      return
    end

    if @main_size + @buffer_size <= @size
      # the buffer is full.
      bulk_insert
      @min = ROOT # the location of the minimal value
      @buffer_min = nil

      # Edelkamp suggests a buffer size of 2 + lg(n).ceil
      @buffer_size = 2 + (Math.log(@size) / Math.log(2)).ceil
    end

    # Now there is space in the buffer. Just put the value there
    assign(d, @size)
    @r[size] = 0

    # TODO: there is a way to avoid a comparison here if @buffer_min is already set and we don't become the new buffer min
    if @buffer_min
      count(:comparison)
      @buffer_min = @size if priority < @data[@buffer_min].priority
    else
      @buffer_min = @size
    end

    count(:comparison)
    if @min && priority < @data[@min].priority
      @min = @size
    end

    @size += 1
    check_heap_property if @debug
  end

  # Return the top of the help without removing it
  def top
    raise 'Heap is empty!' unless @size > 0

    @data[@min].item
  end

  # Remove and return item with the maximum priority
  #
  # If both, then also return the priority
  def pop(both: false)
    raise 'Heap is empty!' unless @size > 0

    result = @data[@min]
    count(:pop)

    @size -= 1

    if @min == ROOT
      if @size.zero?
        # nothing to do now
      else
        # take the last element as usual. We do this whether or not this value is in the insertion buffer.
        assign(@data[@size], ROOT)
        @data[@size] = nil
        @main_size -= 1 unless @buffer_min # there is no buffer, so @main_size shrank as well
        sift_down(ROOT) if @size > 1

        if @buffer_min == @size
          # we just put the minimal value of the buffer into the main heap, which must therefore contain the actual minimum of the
          # whole data strcuture
          find_buffer_min(@size - 1)
          @min = ROOT
        elsif @min == ROOT && @buffer_min
          # The root of the main heap was the minimal value of the whole structure. We must see where the new minimal value is
          count(:comparison)
          @min = @buffer_min if @data[@buffer_min].priority < @data[ROOT].priority
        end
      end
    else
      # The minimal value is in the buffer
      assign(@data[@size], @min) unless @size == @min
      @data[@size] = nil
      find_buffer_min

      if @buffer_min
        count(:comparison)
        @min = @data[@buffer_min].priority < @data[ROOT].priority ? @buffer_min : ROOT
      end
    end

    @index_of.delete(result) if @addressable

    check_heap_property if @debug

    return result.item unless both

    [result.item, result.priority]
  end

  # The priority of element has changed
  def update(element, priority)
    raise 'Operation update not supported by this hash' unless @addressable

    priority *= -1 if @max_heap

    idx = @index_of[element]
    old = @data[idx].priority
    @data[idx].priority = priority
    return if priority == old # nothing has changed

    count(:comparison)
    if idx < @main_size
      if priority > old
        sift_down(idx)
      else
        sift_up(idx)
      end
    else
      # We are in the buffer
      if priority > old
        if @idx == @buffer_min
          find_buffer_min
          count(:comparison)
          @min = @data[@buffer_min].priority < @data[ROOT].priority ? ROOT : @buffer_min
        end
      else
        unless idx == @buffer_min
          count(:comparison)
          find_buffer_min
          @min = @data[@buffer_min].priority < @data[ROOT].priority ? @buffer_min : ROOT
        end
      end
    end

    count(:update)

    check_heap_property if @debug
  end

  def addressable?
    @addressable
  end

  def metrics
    raise 'No metrics recorded' unless @metrics

    @metrics
  end

  # Filter the value, v, at index j, up to its correct location.
  #
  # Starting from location j, while e is not at the root node and is smaller than the element at its distinguished ancestor, we swap
  # the two elements, flip the reversal bit of the node tha t previously contained e, and repeat
  private def sift_up(j)
    while j != ROOT
      i = d_ancestor(j)
      break if join(i, j)

      j = i
    end

    count(:sift_up)
  end

  # Filter the value at index down to its correct location. This means re-establishing the weak-heap property between the element at
  # location j and those in its right subtree. Edelkamp et al.:
  #
  #   Starting from the right child of a_j, the last node on the left spine of the right subtree of a_j is identified. The path from
  #   this node to the right child of a_j is traversed upwards, and join operations are rpeatedly pefromed between a_j and the nodes
  #   along this path. The correctness of sift-down follows from the fact that, after each join, the element at location j is less
  #   than or equal to ervery element in the left subtree of the node considered in the next join.
  private def sift_down(j)
    count(:sift_down)

    k = 2 * j + 1 - @r[j] # right child node
    return if k >= @main_size # no right child so nothing to do

    while 2 * k + @r[k] < @main_size
      k = 2 * k + @r[k] # follow left children down spine of right subtree
    end
    until k == j
      join(j, k)
      k >>= 1
    end
  end

  # See Edelkamp et al, section 3, especially Fig 9.
  private def bulk_insert
    right = @size - 1
    left = [@main_size, right / 2].max
    @main_size = @size
    while right > left + 1
      left >>= 1
      right >>= 1
      (left..right).each { |j| sift_down(j) }
    end

    # I don't really understand what is going on here
    [left, right].each do |j|
      next if j.zero?

      i = d_ancestor(j)
      sift_down(i)
      sift_up(i)
    end
  end

  # Put the pair in the given heap location
  private def assign(pair, idx)
    count(:assign)
    @data[idx] = pair
    @index_of[pair.item] = idx if @addressable
  end

  private def swap(idx1, idx2)
    @data[idx1], @data[idx2] = @data[idx2], @data[idx1]
    if @addressable
      @index_of[@data[idx1].item] = idx1
      @index_of[@data[idx2].item] = idx2
    end
  end

  private def find_buffer_min(size = @size)
    @buffer_min = nil
    return unless @size > @main_size

    @buffer_min = @main_size
    min_p = @data[@main_size].priority

    ((@main_size + 1)...size).each do |i|
      count(:comparison)
      p = @data[i].priority
      if p < min_p
        min_p = p
        @buffer_min = i
      end
    end
  end

  # Conceptually "join" weak heaps into one weak heap, given the following assumption:
  #
  #   Let a_i and a_j be elements in a weak heap such that a_i is less than or equal to every element in the left stubree of
  #   a_j and a_i is not a descendant of a_j. (Idea: a_j and its right subtree form a weak tree, and a_i and the left subtree of a_j
  #   form another weak heap.)
  #
  # Return true if we didn't have to swap them
  private def join(idx1, idx2)
    count(:comparison)
    if @data[idx2].priority < @data[idx1].priority
      swap(idx1, idx2)
      @r[idx2] = 1 - @r[idx2]
      false
    else
      true
    end
  end

  private def parent(idx)
    idx / 2
  end

  # The "distinguished ancestor" of the given index/node. This is the first ancestor of which idx is in the right subtree.
  private def d_ancestor(idx)
    idx >>= 1 while (idx & 1) == @r[idx >> 1]
    idx >> 1
  end

  private def left_child(idx)
    2 * idx + @r[idx]
  end

  private def right_child(idx)
    2 * idx + 1 - @r[idx]
  end

  private def count(stat)
    return unless @metrics

    @metrics[stat] += 1
  end

  private def check_heap_property
    x, y = heap_property_violation
    raise "Heap property violated at descendant #{y} of #{x}" if x

    raise "@min does not point to the minimal value" if @min.positive? && @data[ROOT].priority < @data[@min].priority
  end

  # For debugging. Return a [idx, decendant] pair that violates the weak heap proeprty if there is such, and nil otherwise
  private def heap_property_violation()
    (ROOT...@main_size).each do |idx|
      next if idx == ROOT

      da = d_ancestor(idx)

      return [da, idx] if @data[idx].priority < @data[da].priority
    end
    nil
  end
end
