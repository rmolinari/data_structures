require 'test/unit'
require_relative 'heap'
require_relative 'weak_heap'
require_relative 'weak_heap_insert_buffer'

require 'byebug'

class HeapTest < Test::Unit::TestCase

  def test_heap
    check_heap_sort(Heap)
    check_heap_sort(WeakHeap)
    check_heap_sort(WeakHeapInsertBuffer)
  end

  def test_weak_heap_insert_buffer
    # This data exercised a bug
    data = [654,333,878,744,553,539,354,147,35,383,446,866,782,151,91,438]
    check_heap_sort(WeakHeapInsertBuffer, data)
  end

  # Do a simple heap sort and check that things are OK
  private def check_heap_sort(heap_klass, data = nil)
    data ||= (0...1000).to_a.shuffle

    heap = heap_klass.new(debug: !true)

    data.each do |v|
      heap.insert(v, v)
    end

    # # Now change all the priorities
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
end
