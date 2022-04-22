# An addressable heap that can be used for a priority queue.
#
# Internally it is a simple binary heap
#
# By default it is a min-heap but can be a max-heap via a configuration parameter.
#
# We provide
# - #empty?
#   - O(1)
# - #insert
#   - O(log N)
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
# Parameters:
#
# - max_heap, default false
#   - if true we implement a max-heap by negating the priorities
class Heap
  # index from 1. @data[0] is never used
  ROOT = 1

  attr_reader :size

  Pair = Struct.new(:priority, :item)

  # Arguments:
  #
  # - max_heap: if truthy then implement a max-heap rather than the default min-heap
  # - addressable: if truthy then the heap supports #update
  # - knuth: use Knuth's approach in sift_down (5.2.3-18)
  # - debug: if truthy check the heap property after certain operations
  # - metrics: if truthy keep track of updates, inserts, pops, sift-ups, and sift-downs
  def initialize(max_heap: false, addressable: true, knuth: false, debug: false, metrics: false)
    @data = []
    @size = 0
    @max_heap = max_heap
    @debug = debug
    @metrics = Hash.new(0) if metrics
    @addressable = addressable
    @knuth = knuth
    @index_of = {} if @addressable
  end

  def empty?
    @size == 0
  end

  def insert(value, priority)
    priority *= -1 if @max_heap

    @size += 1

    d = Pair.new(priority, value)
    assign(d, @size)

    sift_up(@size)
  end

  # Return the top of the help without removing it
  def top
    raise 'Heap is empty!' unless @size > 0

    @data[ROOT].item
  end

  # Remove and return item with the maximum priority
  def pop
    result = top
    @index_of.delete(result) if @addressable

    assign(@data[@size], ROOT)

    @data[@size] = nil
    @size -= 1

    sift_down(ROOT) if @size.positive?

    count(:pop)

    result
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

  def metrics
    raise 'No metrics recorded' unless @metrics

    @metrics
  end

  # Filter the value at index up to its correct location. Algorithm from Edelkamp et. al.
  private def sift_up(idx)
    return if idx == ROOT

    x = @data[idx]
    while idx != ROOT
      i = parent(idx)
      count(:comparison)
      break unless x.priority < @data[i].priority

      assign(@data[i], idx)
      idx = i
    end
    assign(x, idx)

    count(:sift_up)
    check_heap_property if @debug
  end

  # Filter the value at index down to its correct location. Algorithm from Edelkamp et. al.

  # The normal way of doing this is, at each level, compare the value of interest and both children to find the largest one. This
  # means two comparisons at each level. So if the value needs to be moved down L levels in the heap we do 2L comparisons.

  # But a "typical" value in a heap (assuming entries are uniformly distributed) belongs near the bottom, because the bottom of a
  # binary tree is "large". This is even more so after a pop, because the value we are sifting down from the root was already at the
  # bottom of the tree and so may well end up there again. So with some waving of hands we can say that L ~= lg n - 1.

  # This is all pointed out in Knuth 5.2.3-18 (Sorting and Searching). Instead of comparing with the value being sifted down, just
  # compare the children, and move a "hole" (that is, the place we will eventually put the item being sifted) down the heap all the
  # way to the bottom. This requires lg n comparisons. Then go back up the path just taken to find the right place for the value
  # being sifted down. This means lg n - L ~= 1 comparison. So we end up doing roughly lg n + 1 comparisons instead of 2 lg n - 1
  # for a gain of lg n - 2.

  # On the downside, we do more assignments. We have to update @data lg n + 1 times instead of lg n - 1 times. This is nothing to
  # worry about since array access is cheap. But we also have to update @index_of, which is a hash, which means calling the hash
  # function more often. In practice this seems to slow things down overall.
  private def sift_down(idx)
    count(:sift_down)
    if @knuth
      x = @data[idx]

      while (j = left_child(idx)) <= @size
        if j + 1 <= @size
          count(:comparison)
          j += 1 if @data[j + 1].priority < @data[j].priority
        end

        assign(@data[j], idx)
        idx = j
      end
      # Now head back up the heap to find the right place for x
      loop do
        j = idx
        idx = parent(idx)

        count(:comparison)
        break if j == ROOT || @data[idx].priority <= x.priority

        assign(@data[idx], j)
      end

      assign(x, j)
    else
      x = @data[idx]

      while (j = left_child(idx)) <= @size
        if j + 1 <= @size
          j += 1 if @data[j + 1].priority < @data[j].priority
          count(:comparison)
        end

        count(:comparison)
        break unless @data[j].priority < x.priority

        assign(@data[j], idx)
        idx = j
      end
      assign(x, idx)
    end

    check_heap_property if @debug
  end

  # Put the pair in the given heap location
  private def assign(pair, idx)
    @data[idx] = pair
    @index_of[pair.item] = idx if @addressable
    count(:assign)
  end

  private def parent(idx)
    idx / 2
  end

  private def left_child(idx)
    2 * idx
  end

  private def right_child(idx)
    2 * idx + 1
  end

  private def count(stat)
    return unless @metrics

    @metrics[stat] += 1
  end

  # For debugging
  private def check_heap_property
    (ROOT..@size).each do |idx|
      left = left_child(idx)
      right = right_child(idx)

      raise "Heap property violated by left child of index #{idx}" if left <= @size && @data[idx].priority >= @data[left].priority
      raise "Heap property violated by right child of index #{idx}" if right <= @size && @data[idx].priority >= @data[right].priority
    end
  end
end
