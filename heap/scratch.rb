require_relative 'heap'
require_relative 'weak_heap'
require_relative 'weak_heap_insert_buffer'

require 'byebug'

heap_klass = WeakHeap
data = (0...300_000).to_a.shuffle
heap = heap_klass.new

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
  raise "Data not sorted! " if last && v > last
  last = v
end
