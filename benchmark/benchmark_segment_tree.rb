$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'benchmark'
require 'byebug'

require 'data_structures_rmolinari'

MaxValSegmentTree = DataStructuresRMolinari::MaxValSegmentTree

class Randomizer
  def initialize(size)
    @size = size
    print "Generating #{size} random values in [-1, 1]..."
    @random_floats = (0..size).map { 2 * rand - 1 }
    puts "done"

    print "Generating #{size} pairs of random integers in 0...#{size}..."
    @random_int_pairs = (0..size).map do
      v1 = rand(size)
      v2 = rand(size)
      if v1 > v2
        [v2, v1]
      else
        [v1, v2]
      end
    end
    puts "done"
  end

  def make_seg_tree(lang)
    case lang
    when :ruby
      MaxValSegmentTree.construct(@random_floats)
    when :c
      MaxValSegmentTree.construct_c(@random_floats)
    else
      raise "No implementation for lang #{lang}"
    end
  end

  def operate(seg_tree)
    @random_int_pairs.each do |v1, v2|
      seg_tree.max_on(v1, v2)
    end
  end
end

size = Integer(ENV['test_size'] || 1_000_000)
seg_tree = c_seg_tree = nil

puts <<~MSG
  I am going to generate a list of #{size} random numbers on [-1, 1].

  Then I will create two MaxValSegmentTree instances over this list. One will be
  of the pure Ruby class and the other of the one written as a C extension.

  I am also going to generate #{size} pairs of random integers in 0...#{size}.

  Then, for each MaxValSegmentTree instance, I will perform a sequence
  of #{size} max_on(i, j) operations, using the random integer pairs as
  inputs. The instances will get the same sequence of arguments.

  Timing data will be output for
    - the construction of each MaxValSegmentTree instance, and
    - the overall sequence of #max_on operations.


MSG

randomizer = Randomizer.new(size)

puts
puts "Now I will construct the MaxValSegmentTree instances..."
Benchmark.bm(10) do |x|
  x.report("ruby init") { seg_tree = randomizer.make_seg_tree(:ruby) }
  x.report("C init") { c_seg_tree = randomizer.make_seg_tree(:c) }
end

puts "...done"
puts

puts "And now the same sequence of #{size} #max_on operations on each segment tree..."
Benchmark.bm(10) do |x|
  x.report("ruby op") { randomizer.operate(seg_tree) }
  x.report("C op") { randomizer.operate(c_seg_tree) }
end
puts "...done"
