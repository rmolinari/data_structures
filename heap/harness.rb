#!/usr/bin/env ruby

require 'byebug'
require 'set'

require_relative 'heap'

# Some simple harness code to experiment with different Hash implementations
# Scope and such
class Harness
  INFINITY = Float::INFINITY

  # Use a heap to sort a randomly shuffled array of integers. Return the metrics from the heap
  def heapsort(data, heap)
    start_t = Time.now

    # "Priority" is just the value
    data.each { |v| heap.insert(v, v) }

    # Now extract the values. Let's not bother putting them into an array because it's the heap performance we're interested in.
    prev = nil
    until heap.empty?
      v = heap.pop
      raise 'Values not sorted!' if prev && v < prev

      prev = v
    end

    metrics = heap.metrics
    metrics[:elapsed] = Time.now - start_t
    metrics
  end

  # heap_makers is a hash :label -> lambda, for which the lambda returns a new heap with whatever desired properties. The heap is
  # expected to respond to the #metrics method.
  def heapsorts(heap_makers)
    metrics = {}
    [1, 2, 3, 4, 5].each do |multiple|
      size = multiple * 10**6
      data = (1..size).to_a.shuffle

      heap_makers.each do |label, maker|
        print "Using heap #{label} to sort array of size #{size}..."

        metrics[label] ||= {}
        metrics[label][size] = heapsort(data, maker.call)

        # Heap sort is O(n ln n). Let's estimate the coefficient
        metrics[label][size][:coeff] = "%0.3e" % (metrics[label][size][:elapsed] / (size * Math.log(size)))
        puts "done in #{metrics[label][size][:elapsed]} s"
      end
      puts
    end

    # Yuck!
    headers = metrics.values.map {|h| h.values }.flatten.map(&:keys).flatten.uniq
    metrics.each do |label, sub_metrics|
      output_stats(label, sub_metrics, headers)
      puts
    end
  end

  # Use a simple Dijkstra to find all shortest paths from start, using the given heap as priority queue
  #
  # All edges are of length 1
  def dijkstra(start, neighbors, heap)
    start_t = Time.now
    distance_to = Hash.new(INFINITY)
    distance_to[start] = 0

    unvisited = heap
    unvisited.insert(start, 0)

    loop do
      break if unvisited.empty?
      break if distance_to[unvisited.top] == INFINITY

      node = unvisited.pop
      d = distance_to[node]
      neighbors[node].each do |v|
        total = 1 + d
        old_distance = distance_to[v]
        next unless total < old_distance

        distance_to[v] = total
        if old_distance == INFINITY
          unvisited.insert(v, total)
        else
          unvisited.update(v, total)
        end
      end
    end
    metrics = heap.metrics
    metrics[:elapsed] = Time.now - start_t
    metrics
  end

  def shortest_paths(heap_makers, graph_maker)
    metrics = {}
    [1, 2, 3, 4, 5].each do |multiple|
      size = multiple * 50_000
      start, neighbors = graph_maker.call(size) # make a desired sort of graph

      heap_makers.each do |label, heap_maker|
        print "Using heap #{label} with Dijkstra to find all-nodes shortest in graph of #{size}..."

        metrics[label] ||= {}
        metrics[label][size] = dijkstra(start, neighbors, heap_maker.call)

        puts "done in #{metrics[label][size][:elapsed]} s"
      end
      puts
    end
    headers = metrics.values.map {|h| h.values }.flatten.map(&:keys).flatten.uniq
    metrics.each do |label, sub_metrics|
      output_stats(label, sub_metrics, headers)
      puts
    end
  end

  # - label appears in a heading
  # - each element of all_metrics is a header -> value hash
  # - headers is the list of headers to use, in order
  def output_stats(label, all_metrics, headers)
    puts "Stats for #{label}"
    puts (['size'] + headers).map{ |v| v.to_s.rjust(15) }.join
    all_metrics.sort.each do |size, metrics|
      vals = [size] + headers.map{ |hdr| metrics[hdr] }
      puts vals.map { |v| v.to_s.rjust(15) }.join
    end
  end

  # Generate a "random" directed graph with some nice properties.
  #
  # See D. Chakrabarti, Y. Zhan, and C. Faloutsos. R-MAT: A recursive model for graph mining. In Proc. 4th SIAM Intl Conf on Data
  # Mining, Orlando, Florida, 2004.
  #
  # Roughly:
  # - divide a 2^N * 2^N matrix into 4 equal portions and "move" into one with probabilities a, b, c, d. Do this recursively until
  #   we are in a 1x1 square, and put an edge there. We end up with an adjacency matrix.
  #
  # - size is the desired number of nodes
  # - density is the desired number of outgoing edges per node
  #
  # According to Chen, Chowdhury, Ramachandran, Roche, Tong, _Priority Queues and Dijkstra's Algorithm_, values (a, b, c, d) =
  # (0.45, 0.15, 0.15, 0.25) give graphs that a reasonably "real-world"
  #
  # Writing this myself is Ruby was very, very slow. So we use an external program, PaMAT
  #
  # Use an external generator to build a graph using the R-MAT approach
  def self.r_mat_graph_external(size, density, probs = [0.45, 0.15, 0.15, 0.25])
    a, b, c, d = probs
    cmd = "parmat -nVertices #{size} -nEdges #{size * density} -a #{a} -b #{b} -c #{c} -d #{d} -sorted -output /dev/stderr 2>&1 > /dev/null"

    require 'open3'

    edges = []
    Open3.popen3(cmd) do |stdout, stderr, _status, _thread|
      while line = stderr.gets
        from, to = line.split.map(&:to_i)
        edges[from] ||= Set.new
        edges[from] << to
      end
    end
    (0...size).each { |n| edges[n] ||= [] }
    edges
  end
end

if false
  Harness.new.heapsorts(
    {
      binary_addressable: (-> { Heap.new(metrics: true) }),
      binary: (-> { Heap.new(addressable: false, metrics: true) }),
      binary_addressable_knuth: (-> { Heap.new(knuth: true, metrics: true) }),
      binary_knuth: (-> { Heap.new(addressable: false, knuth: true, metrics: true) })
    }
  )
end

# #Harness.r_mat_graph(75_000, 15)
# g = Harness.r_mat_graph_external(100, 20)
# byebug

Harness.new.shortest_paths(
  {
    binary_addressable: (-> { Heap.new(metrics: true) }),
    binary_addressable_knuth: (-> { Heap.new(knuth: true, metrics: true) }),
  },
  lambda do |graph_size|
    edge_count = Math.sqrt(graph_size).ceil / 3
    t = Time.now
    print "generating graph of size #{graph_size} and about #{edge_count} outgoing edges per node..."
    g = Harness.r_mat_graph_external(graph_size, edge_count)
    puts "...done in #{Time.now - t} s"
    [0, g]
  end
)
