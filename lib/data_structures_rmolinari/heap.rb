require_relative 'shared'

# A heap is a balanced binary tree in which each entry has an associated priority. For each node p of the tree that isn't the root,
# the priority of the element at p is not less than the priority of the element at the parent of p.
#
# Thus the priority at each node p - root or not - is no greater than the priorities of the elements in the subtree rooted at p. It
# is a "min-heap".
#
# We can make it a max-heap, in which each node's priority is no greater than the priority of its parent, via a parameter to the
# initializer.
#
# We provide the following operations
# - +empty?+
#   - is the heap empty?
#   - O(1)
# - +insert(item, priority)+
#   - add a new item to the heap with an associated priority
#   - O(log N)
# - +top+
#   - return the lowest-priority element, which is the element at the root of the tree. In a max-heap this is the highest-priority
#     element.
#   - O(1)
# - +pop+
#   - removes and returns the item that would be returned by +top+
#   - O(log N)
# - +update(item, priority)+
#   - tell the heap that the priority of a particular item has changed
#   - O(log N)
#
# Here N is the number of elements in the heap.
#
# The internal requirements needed to implement +update+ have several consequences.
# - Items added to the heap must be distinct. Otherwise we would not know which occurrence to update
# - There is some bookkeeping overhead.
# If client code doesn't need to call +update+ then we can create a "non-addressable" heap that allows for the insertion of
# duplicate items and has slightly faster runtime overall. See the arguments to the initializer.
#
# References:
#
# - https://en.wikipedia.org/wiki/Binary_heap
# - Edelkamp, S., Elmasry, A., Katajainen, J., _Optimizing Binary Heaps_, Theory Comput Syst (2017), vol 61, pp 606-636,
#   DOI 10.1007/s00224-017-9760-2
#
# @todo
#   - let caller see the priority of the top element. Maybe this is useful sometimes.
class DataStructuresRMolinari::Heap
  include Shared
  include Shared::BinaryTreeArithmetic

  # The number of items currently in the heap
  attr_reader :size

  # An (item, priority) pair
  InternalPair = Struct.new(:item, :priority)
  private_constant :InternalPair

  # @param max_heap when truthy, make a max-heap rather than a min-heap
  # @param addressable when truthy, the heap is _addressable_. This means that
  #   - item priorities are updatable with +update(item, p)+, and
  #   - items added to the heap must be distinct.
  #   When falsy, priorities are not updateable but items may be inserted multiple times. Operations are slightly faster because
  #   there is less internal bookkeeping.
  # @param debug when truthy, verify the heap property after each change that might violate it. This makes operations much slower.
  def initialize(max_heap: false, addressable: true, debug: false)
    @data = []
    @size = 0
    @max_heap = max_heap
    @addressable = addressable
    @index_of = {} # used in addressable heaps
    @debug = debug
  end

  # Is the heap empty?
  def empty?
    @size.zero?
  end

  # Insert a new element into the heap with the given priority.
  # @param value the item to be inserted.
  #   - If the heap is addressible (the default) it is an error to insert an item that is already present in the heap.
  # @param (optional) priority the priority to use for new item. The values used as priorities must be totally ordered via +<=>+.
  #        If omitted we use the inserted value as its own priority.
  def insert(value, priority = value)
    raise DataError, "Heap already contains #{value}" if @addressable && contains?(value)

    @size += 1

    d = InternalPair.new(value, priority)
    assign(d, @size)

    sift_up(@size)
  end

  # Return the top of the heap without removing it
  # @return a value with minimal priority (maximal for max-heaps). Strictly speaking, it returns the item at the root of the
  #   binary tree; this element has minimal priority, but there may be other elements with the same priority and they do not appear
  #   at the top of the heap in any guaranteed order.
  def top
    raise 'Heap is empty!' unless @size.positive?

    @data[root].item
  end

  # Return the priority of the item at the top of the heap
  def top_priority
    raise 'Heap is empty!' unless @size.positive?

    @data[root].priority
  end

  # Return the top of the heap and remove it, updating the structure to maintain the necessary properties.
  # @return (see #top)
  def pop
    result = top # raises if empty
    assign(@data[@size], root)

    @data[@size] = nil
    @size -= 1
    @index_of.delete(result) if @addressable

    sift_down(root) if @size.positive?

    result
  end

  # Update the priority of the given element and maintain the necessary heap properties.
  #
  # @param element the item whose priority we are updating. It is an error to update the priority of an element not already in the
  #   heap
  # @param priority the new priority
  def update(element, priority)
    raise LogicError, 'Cannot update priorities in a non-addressable heap' unless @addressable
    raise DataError, "Cannot update priority for value #{element} not already in the heap" unless contains?(element)

    idx = @index_of[element]
    old = @data[idx].priority
    @data[idx].priority = priority
    if less_than_priority?(old, priority)
      sift_down(idx)
    elsif less_than_priority?(priority, old)
      sift_up(idx)
    end

    check_heap_property if @debug
  end

  # Update the priority of the given element by changing the priority by the given amount.
  #
  # @param element the item whose priority we are updating. It is an error to update the priority of an element not already in the
  #   heap
  # @param the amount by which to change the priority. The existing priority must respond sensibly to += with this value
  def update_by_delta(element, delta)
    raise LogicError, 'Cannot update priorities in a non-addressable heap' unless @addressable
    raise DataError, "Cannot update priority for value #{element} not already in the heap" unless contains?(element)

    idx = @index_of[element]
    old = @data[idx].priority

    update(element, old + delta)
  end

  # Filter the value at index up to its correct location. Algorithm from Edelkamp et. al.
  private def sift_up(idx)
    return if idx == root

    x = @data[idx]
    while idx != root
      i = parent(idx)
      break unless less_than?(x, @data[i])

      assign(@data[i], idx)
      idx = i
    end
    assign(x, idx)

    check_heap_property if @debug
  end

  # Filter the value at index down to its correct location. Algorithm from Edelkamp et. al.
  private def sift_down(idx)
    x = @data[idx]

    while (j = left(idx)) <= @size
      j += 1 if j + 1 <= @size && less_than?(@data[j + 1], @data[j])

      break unless less_than?(@data[j], x)

      assign(@data[j], idx)
      idx = j
    end
    assign(x, idx)

    check_heap_property if @debug
  end

  # Put the pair in the given heap location
  private def assign(pair, idx)
    @data[idx] = pair
    @index_of[pair.item] = idx if @addressable
  end

  # Compare the priorities of two items with <=> and return truthy exactly when the result is -1.
  #
  # If this is a max-heap return truthy exactly when the result of <=> is 1.
  #
  # The arguments can also be the priorities themselves.
  private def less_than?(p1, p2)
    less_than_priority?(p1.priority, p2.priority)
  end

  # Direct comparison of priorities
  private def less_than_priority?(priority1, priority2)
    return (priority1 <=> priority2) == 1 if @max_heap

    (priority1 <=> priority2) == -1
  end

  private def contains?(item)
    !!@index_of[item]
  end

  # For debugging
  private def check_heap_property
    (root..@size).each do |idx|
      left = left(idx)
      right = right(idx)

      raise InternalLogicError, "Heap property violated by left child of index #{idx}" if left <= @size && less_than?(@data[left], @data[idx])
      raise InternalLogicError, "Heap property violated by right child of index #{idx}" if right <= @size && less_than?(@data[right], @data[idx])
    end
  end
end
