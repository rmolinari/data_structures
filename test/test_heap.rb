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
end
