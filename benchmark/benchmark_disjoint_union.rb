$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'benchmark'
require 'byebug'

require 'data_structures_rmolinari'

DisjointUnion = DataStructuresRMolinari::DisjointUnion
CDisjointUnion = DataStructuresRMolinari::CDisjointUnion

class Randomizer
  def initialize(size)
    @size = size
    print "Generating #{3 * size} random integers in 0...#{size}..."
    @randoms = (0..(3 * size)).map { rand(size) }
    puts "done"
  end

  def operate(du)
    (0..(@size/2)).each do |idx|
      # unite two elements
      e1 = @randoms[2 * idx]
      e2 = @randoms[2 * idx + 1]
      next if e1 == e2

      du.unite(e1, e2)
    end
  end
end

size = Integer(ENV['test_size'] || 10_000_000)
disjoint_union = c_disjoint_union = nil

puts <<~MSG

  I am going to create two DisjointUnion instances. One will be of the pure Ruby
  class and the other of the one written as a C extension. Each will have a
  universe of size #{size}.

  I will also generate #{3 * size} random integers in 0...#{size}.

  Then, for each DisjointUnion instance, I will perform a sequence of #{size / 2}
  #unite operations, using the random integers as inputs. The instances will get the
  same sequence of arguments.

  Timing data will be output for
    - the construction of each DisjointUnion instance, and
    - the overall sequence of #unite operations.


MSG

randomizer = Randomizer.new(size)

puts
puts "Now I will construct the Disjoint Union instances..."
Benchmark.bm(10) do |x|
  x.report("ruby init") { disjoint_union = DisjointUnion.new(size) }
  x.report("C init") { c_disjoint_union = CDisjointUnion.new(size) }
end

puts "...done"
puts

puts "And now the same sequence of #{size/2} #unite operations on each DisjointUnion..."
Benchmark.bm(10) do |x|
  x.report("ruby op") { randomizer.operate(disjoint_union) }
  x.report("C op") { randomizer.operate(c_disjoint_union) }
end
puts "...done"
