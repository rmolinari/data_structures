# Data Structures

This is a small collection of Ruby data structures that I have implemented for my own interest. Implementing the code for a data
structure is almost always more educational than simply reading about it and is usually fun.

These implementations are not particularly clever. They are based on the expository descriptions and pseudo-code I found as I read
about each structure and so are not as fast as possible.

The code is available in gem form: https://rubygems.org/gems/data_structures_rmolinari.

## Usage

The right way to organize the code is not obvious to me. For now the data structures are all defined in the module
`DataStructuresRMolinari` to avoid polluting the global namespace.

Example usage after the gem is installed:
```
require 'data_structures_rmolinari`

MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
Point = DataStructuresRMolinari::Point # anything responding to :x and :y is fine

pst = MaxPrioritySearchTree.new([Point.new(1, 1)])
puts pst.highest_ne(0, 0) # "Point(1,1)"
```

## Implementations

### Disjoint Union

We represent the set S(n) = {0, 1, ..., n-1} as the disjoint union of subsets. Alternatively, we represent a partition of S(n). The
data structure provides very efficient implementation of the two key operations
- `unite(e, f)`, which merges the subsets containing e and f; and
- `find(e)`, which returns the canonical representative of the subset containing e. Two elements e and f are in the same subset
  exactly when `find(e) == find(f)`.

For more details see https://en.wikipedia.org/wiki/Disjoint-set_data_structure and the paper by Tarjan and van Leeuwen.[^tarjan]

### Heap

A binary heap with an `update` method, suitable for use as a priority queue. There are several supported operations:
- `insert(item, priority)`, insert the given item with the stated priority.
  - By default, items must be distinct.
- `top`, returning the element with smallest priority
- `pop`, return the element with smallest priority and remove it from the structure
- `update(item, priority)`, update the priority of the given item, which must already be in the heap

`top` is O(1). The others are O(log n) where n is the number of items in the heap.

By default we have a min-heap: the top element is the one with smallest priority. A configuration parameter at construction makes it
a max-heap.

Another configuration parameter allows the creation of a "non-addressable" heap. This makes it impossible to call `update`, but
allows the insertion of duplicate items (which is sometimes useful) and slightly faster operation overall.

See https://en.wikipedia.org/wiki/Binary_heap and Edelkamp et al.[^edelkamp]

### Priority Search Tree

A PST stores a set P of two-dimensional points in a way that allows certain queries about P to be answered efficiently.
- `highest_ne(x0, y0)` and `highest_nw(x0, y0)`, the highest point in the quadrant to the northest/northwest of (x0, y0);
- `leftmost_ne(x0, y0)`, the leftmost point in the quadrant to the northeast of (x0, y0);
- `rightmost_nw(x0, y0)`, the rightmost point in the quadrant to the northwest of (x0, y0);
- `highest_3_sided(x0, x1, y0)`, the highest point in the region specified by x0 <= x <= x1 and y0 <= y; and
- `enumerate_3_sided(x0, x1, y0)`, enumerate all the points in that region.

The single-point queries run in O(log n) time, where n is the size of P, while `enumerate_3_sided` runs in O(m + log n), where m is
the number of points actually enumerated.

Here compass directions are the natural ones in the x-y plane with the positive x-axis pointing east and the positive y-axis
pointing north. "Left", "right", and "highest" mean "west", "east", and "north".  The use of both compass directions and
left/right/highest is confusing but comes from the papers. We will probably switch them all to compass-words soon.

The implementation is in `MaxPrioritySearchTree`.

See the papers McCreight[^mccreight] and De et al.[^de_2011]

De et al. generalize the structure to a _Min-max Priority Search Tree_ (MinmaxPST) that can also answer queries in the southeast and
southwest quadrants.[^de_2013] But the presentiation is hard to follow in places and the pseudocode is buggy. See the fragmentary
code in the class `MinMaxPrioritySearchTree` for further details.

### Segment Tree

Segment trees store information related to subintervals of a certain array. For example, they can be used to find the sum of the
elements in an arbitrary subinterval A[i..j] of an array A[0..n] in O(log n) time. Each node in the tree corresponds to a subarray
of A in such a way that the values we store in the nodes can be combined efficiently to determined the desired result for arbitrary
subarrays.

An excellent description of the idea is found at https://cp-algorithms.com/data_structures/segment_tree.html.

There is a generic implementation (perhaps better described as "abstract"), `GenericSegmentTree`, and concrete classes
`MaxValSegmentTree` and `IndexOfMaxValSegmentTree`. The generic implementation is such that concrete classes can be written by
providing a handful of (usually) simple lambdas and constants to the generic class's initializer. Working out the details require
some knowledge of the internal mechanisms of a segment tree, for which the link at cp-algorithms.com is very helpful. See the
definitions of the concrete classes for examples.

## References
[^edelkamp]: Edelkamp, S., Elmasry, A., Katajainen, J., _Optimizing Binary Heaps_, Theory Comput Syst (2017), vol 61, pp 606-636, DOI 10.1007/s00224-017-9760-2
[^mccreight]: McCreight, E.M., _Priority Search Trees_, SIAM J. Comput., 14(2):257-276, 1985.
[^de_2011]: De, M., Maheshwari, A., Nandy, S. C., Smid, M., _An In-Place Priority Search Tree_, 23rd Canadian Conference on Computational Geometry, 2011
[^de_2013]: De, M., Maheshwari, A., Nandy, S. C., Smid, M., _An In-Place Min-max Priority Search Tree_, Computational Geometry, v46 (2013), pp 310-327.
[^tarjan]: Tarjan, Robert E., van Leeuwen, Jan (1984). _Worst-case Analysis of Set Union Algorithms_. Journal of the ACM. 31 (2): 245–281.
