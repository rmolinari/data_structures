# An addressable heap that can be used for a priority queue.
#
# It implements the "weak heap" data structure described here:
#
#   Edelkamp, S., Elmasry, A., Katajainen, J., _The weak-heap data structure: Variants and applications_, Journal of Discrete
#   Algorithms, 2012, v16, pp 187-205.
#
# A weak heap relaxes the requirements for a heap. Each element is less than or equal to all the elements in its right subtree.
#
# We provide
# - #empty?
#   - O(1)
# - #insert
#   - O(log N)
#   - This becomes O(1) (amortized) if we can implement bulk insertion
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
# The idea was to find a faster data structure for the priority queue in Dijkstra, but this "weak" approach is no quicker in
# practice than a plain, nonaddressable binary heap. It appears to be slightly faster than the binary heap for heapsort, presumably
# because in that case we add so many elements to an already large heap.
class WeakHeap
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

    @size = 0
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
    assign(d, @size)
    @r[@size] = 0
    if (@size % 1).zero?
      # If we are the only child of our parent, set the flip bit so we are actually a left child, saving a comparison.
      @r[@size >> 1] = 0
    end

    sift_up(@size)

    @size += 1
  end

  # Return the top of the help without removing it
  def top
    raise 'Heap is empty!' unless @size > 0

    @data[ROOT].item
  end

  # Remove and return item with the maximum priority
  #
  # If both, then also return the priority
  def pop(both: false)
    result = @data[ROOT]

    @index_of.delete(result) if @addressable

    @size -= 1

    assign(@data[@size], ROOT)
    @data[@size] = nil

    sift_down(ROOT) if @size > 1

    count(:pop)

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
    if priority > old
      sift_down(idx)
    elsif priority < old
      sift_up(idx)
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
    check_heap_property if @debug
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
    while (l = 2 * k + @r[k]) < @size
      k = l # follow left children down spine of right subtree
    end
    until k == j
      join(j, k)
      k >>= 1
    end

    check_heap_property if @debug
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

  # Conceptually "join" weak heaps into one weak heap, given the following assumption:
  #
  #   Let a_i and a_j be elements in a weak heap such that a_i is less than or equal to every element in the left stubree of
  #   a_j and a_i is not a descendant of a_j. (Idea: a_j and its right subtree form a weak tree, and a_i and the left subtree of a_j
  #   form another weak heap.)
  #
  # Return true if we didn't have to swap them
  private def join(idx1, idx2)
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

  # For debugging
  private def check_heap_property
    (ROOT...@size).each do |idx|
      next if idx == ROOT

      da = d_ancestor(idx)
      raise "Heap property violated at descendant #{idx} of #{da}" if @data[idx].priority < @data[da].priority
    end
  end

  # The priorities of the element and idx and all its decendants should be no smaller than the priority of the value at i
  private def check_bound(idx, i)
    return if idx >= @size
    raise "Heap property violated at descendant #{idx} of #{i}" if @data[idx].priority < @data[i].priority

    check_bound(left_child(idx), i)
    check_bound(right_child(idx), i)
  end
end
