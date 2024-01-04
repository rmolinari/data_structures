require 'byebug'
require 'test/unit'

require 'data_structures_rmolinari'

Heap = DataStructuresRMolinari::Heap

class HeapTest < Test::Unit::TestCase
  def test_basic_operation
    data = [
      32, 5, 43, 49, 8, 15, 29, 50, 13, 25, 46, 48, 2, 14, 10, 35, 9, 18, 36, 40, 11, 21, 33, 4, 42, 20, 17, 19, 22, 38, 24, 23, 16,
      28, 7, 3, 39, 34, 12, 41, 37, 6, 31, 26, 1, 30, 45, 47, 44, 27
    ]
    heap = Heap.new(debug: true)

    data.each do |v|
      heap.insert(v, v)
    end

    # Now change all the priorities
    data.each do |v|
      heap.update(v, -v)
    end

    # Try sorting
    last = nil
    until heap.empty?
      v = heap.pop
      assert_compare(last, ">", v) if last
      last = v
    end
  end

  def test_sort_with_min_heap
    data = (1..50).to_a.shuffle
    heap = Heap.new
    data.each { |v| heap.insert(v, v) }

    tops = []
    tops << heap.pop until heap.empty?

    assert(tops.each_cons(2).all? { |x, y| x < y })
  end

  def test_sort_with_max_heap
    data = (1..50).to_a.shuffle
    heap = Heap.new(max_heap: true)
    data.each { |v| heap.insert(v, v) }

    tops = []
    tops << heap.pop until heap.empty?

    assert(tops.each_cons(2).all? { |x, y| x > y })
  end

  def test_duplicate_enforcement
    heap = Heap.new

    heap.insert(1, 1)
    assert_raise(Shared::DataError) do
      heap.insert(1, 0)
    end
  end

  def test_membership_enforcement_for_update
    heap = Heap.new

    assert_raise(Shared::DataError) do
      heap.update(1, 1)
    end

    heap.insert(1, 1)
    heap.pop
    assert_raise(Shared::DataError) do
      heap.update(1, 1)
    end
  end

  def test_arrays_as_priorities
    data = (1..50).to_a.shuffle
    heap = Heap.new
    data.each { |v| heap.insert(v, [v]) }

    tops = []
    tops << heap.pop until heap.empty?

    assert(tops.each_cons(2).all? { |x, y| x < y })
  end

  def test_unaddressable_heap
    heap = Heap.new(addressable: false)

    heap.insert(1, 2)
    heap.insert(2, 1)
    heap.insert(1, 0) # allowed!
    assert_equal 1, heap.pop
    assert_equal 2, heap.pop
    assert_equal 1, heap.pop

    heap.insert(1, 2)
    assert_raise(Shared::LogicError) do
      heap.update(1, 0)
    end
  end

  def test_heap_with_no_priorities
    heap = Heap.new

    heap.insert(3)
    heap.insert(2)
    heap.insert(1)
    assert_equal 1, heap.pop
    assert_equal 2, heap.pop
    assert_equal 3, heap.pop
  end

  def test_heap_delta_priorities
    test_pop_ordering([1, 2, 3], [2, 3, 1]) do |heap|
      heap.update_by_delta(1, 3)
    end

    test_pop_ordering([1, 2, 3], [3, 1, 2]) do |heap|
      heap.update_by_delta(3, -3)
    end
  end

  # Create a new Hash, insert the given items, yield the hash to a block, and then assert that the hash pops the items in the given
  # order
  private def test_pop_ordering(inserts, expected_order)
    heap = Heap.new
    inserts.each { |v| heap.insert(v) }

    yield heap

    expected_order.each do |v|
      assert_equal(v, heap.pop)
    end
  end
end
