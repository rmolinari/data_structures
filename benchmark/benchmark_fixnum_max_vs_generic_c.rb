# Compare C segment tree Fixnum fast path (:max) vs generic C path (Ruby lambdas) on the same Fixnum data.
#
# Usage:
#   ruby -Ilib benchmark/benchmark_fixnum_max_vs_generic_c.rb
#   N=500000 Q=2000000 ruby -Ilib benchmark/benchmark_fixnum_max_vs_generic_c.rb
#
# N = array length (Fixnums), Q = number of max_on(left, right) queries (random inclusive ranges).

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'benchmark'

module DataStructuresRMolinari
  module SegmentTree
  end
end

# Minimal load: segment tree C extension only (avoids loading c_disjoint_union).
require 'data_structures_rmolinari/shared'
require 'data_structures_rmolinari/segment_tree_template'
require 'data_structures_rmolinari/c_segment_tree_template'
require 'data_structures_rmolinari/c_segment_tree_template_impl'

CST = DataStructuresRMolinari::SegmentTree::CSegmentTreeTemplate
INF = Shared::INFINITY

n = Integer(ENV.fetch('N', 500_000))
q = Integer(ENV.fetch('Q', 2_000_000))

srand(Integer(ENV.fetch('SEED', 42)))

puts "N=#{n} Fixnums, Q=#{q} random max_on queries (same data, both C templates)"
puts

data = Array.new(n) { rand(-(2**30)..(2**30)) }
pairs = Array.new(q) do
  a = rand(n)
  b = rand(n)
  a <= b ? [a, b] : [b, a]
end

def run_queries(tree, pairs)
  pairs.each { |i, j| tree.query_on(i, j) }
end

fast = generic = nil

Benchmark.bm(24) do |x|
  x.report('generic C build (lambdas)') do
    generic = CST.new(
      combine: ->(a, b) { [a, b].max },
      single_cell_array_val: ->(i) { data[i] },
      size: n,
      identity: -INF
    )
  end
  x.report('fixnum fast C build') do
    fast = CST.new(fixnum_op: :max, data: data, identity: -INF)
  end
  x.report('generic C queries') { run_queries(generic, pairs) }
  x.report('fixnum fast C queries') { run_queries(fast, pairs) }
end

puts
puts 'Sanity: same answer on first 100 queries?', (0...100).all? { |k|
  i, j = pairs[k]
  generic.query_on(i, j) == fast.query_on(i, j)
}
