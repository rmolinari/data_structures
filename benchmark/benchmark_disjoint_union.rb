$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'benchmark'
require 'byebug'

require 'data_structures_rmolinari'

DisjointUnion = DataStructuresRMolinari::DisjointUnion
CDisjointUnion = DataStructuresRMolinari::CDisjointUnion

class Randomizer
  def initialize(size)
    @size = size
    @randoms = (0..(3 * size)).map { rand(size) }
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

randomizer = Randomizer.new(size)

Benchmark.bm(10) do |x|
  x.report("ruby init") { disjoint_union = DisjointUnion.new(size) }
  x.report("C init") { c_disjoint_union = CDisjointUnion.new(size) }
end

Benchmark.bm(10) do |x|
  x.report("ruby op") { randomizer.operate(disjoint_union) }
  x.report("C op") { randomizer.operate(c_disjoint_union) }
end
