# Data Structures

This is a small collection of Ruby data structures that I have implemented for my own interest.  Implementing the code for a data
structure is almost always more educational than simply reading about it and is usually fun.  I wrote some of them while
participating in the Advent of Code (https://adventofcode.com/).

These implementations are not particularly clever. They are based on the expository descriptions and pseudo-code I found as I read
about each structure and so are not as fast as possible.

The code is available as a gem: https://rubygems.org/gems/data_structures_rmolinari.

## Usage

The right way to organize the code is not obvious to me. For now the data structures are all defined in the module
`DataStructuresRMolinari` to avoid polluting the global namespace.

Example usage after the gem is installed:
```
require 'data_structures_rmolinari`

# Pull what we need out of the namespace
MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
Point = DataStructuresRMolinari::Point # anything responding to :x and :y is fine

pst = MaxPrioritySearchTree.new([Point.new(1, 1)])
puts pst.largest_y_in_ne(0, 0) # "Point(1,1)"
```

# Implementations

## Disjoint Union

We represent a set S of non-negative integers as the disjoint union of subsets. Equivalently, we represent a partition of S. The
data structure provides very efficient implementation of the two key operations
- `unite(e, f)`, which merges the subsets containing e and f; and
- `find(e)`, which returns the canonical representative of the subset containing e. Two elements e and f are in the same subset
  exactly when `find(e) == find(f)`.

It also provides
- `make_set(v)`, which adds a new value `v` to the set S, starting out in a singleton subset.

For more details see https://en.wikipedia.org/wiki/Disjoint-set_data_structure and the paper [[TvL1984]](#references) by Tarjan and
van Leeuwen.

## Heap

This is a standard binary heap with an `update` method, suitable for use as a priority queue. There are several supported
operations:

- `insert(item, priority)`, insert the given item with the stated priority.
  - By default, items must be distinct.
- `top`, returning the element with smallest priority
- `pop`, return the element with smallest priority and remove it from the structure
- `update(item, priority)`, update the priority of the given item, which must already be in the heap

`top` is O(1). The others are O(log n) where n is the number of items in the heap.

By default we have a min-heap: the top element is the one with smallest priority. A configuration parameter at construction can make
it a max-heap.

Another configuration parameter allows the creation of a "non-addressable" heap. This makes it impossible to call `update`, but
allows the insertion of duplicate items (which is sometimes useful) and slightly faster operation overall.

See https://en.wikipedia.org/wiki/Binary_heap and the paper by Edelkamp, Elmasry, and Katajainen [[EEK2017]](#references).

## Priority Search Tree

A PST stores a set P of two-dimensional points in a way that allows certain queries about P to be answered efficiently. The data
structure was introduced by McCreight [[McC1985]](#references). De, Maheshawari, Nandy, and Smid [[DMNS2011]](#references) showed
how to build the structure in-place and we use their approach here.

- `largest_y_in_ne(x0, y0)` and `largest_y_in_nw(x0, y0)`, the "highest" (max-y) point in the quadrant to the northest/northwest of
  (x0, y0);
- `smallest_x_in_ne(x0, y0)`, the "leftmost" (min-x) point in the quadrant to the northeast of (x0, y0);
- `largest_x_in_nw(x0, y0)`, the "rightmost" (max-x) point in the quadrant to the northwest of (x0, y0);
- `largest_y_in_3_sided(x0, x1, y0)`, the highest point in the region specified by x0 <= x <= x1 and y0 <= y; and
- `enumerate_3_sided(x0, x1, y0)`, enumerate all the points in that region.

Here compass directions are the natural ones in the x-y plane with the positive x-axis pointing east and the positive y-axis
pointing north.

There is no `smallest_x_in_3_sided(x0, x1, y0)`. Just use `smallest_x_in_ne(x0, y0)`.

(These queries appear rather abstract at first but there are interesting applications. See, for example, section 4 of
[[McC85]](#references), keeping in mind that the data structure in that paper is actually a _MinPST_.)

The single-point queries run in O(log n) time, where n is the size of P, while `enumerate_3_sided` runs in O(m + log n), where m is
the number of points actually enumerated.

The implementation is in `MaxPrioritySearchTree` (MaxPST for short), so called because internally the structure is, among other
things, a max-heap on the y-coordinates.

We also provide a `MinPrioritySearchTree`, which answers analagous queries in the southward-infinite quadrants and 3-sided
regions.

By default these data structures are immutable: once constructed they cannot be changed. But there is a constructor option that
makes the instance "dynamic". This allows us to delete the element at the root of the tree - the one with largest y value (smallest
for MinPST) - with the `delete_top!` method. This operation is important in certain algorithms, such as enumerating all maximal
empty rectangles (see the second paper by De et al.[[DMNS2013]](#references)) Note that points can still not be added to the PST in
any case, and choosing the dynamic option makes certain internal bookkeeping operations slower.

In [[DMNS2013]](#references) De et al. generalize the in-place structure to a _Min-max Priority Search Tree_ (MinmaxPST) that can
answer queries in all four quadrants and both "kinds" of 3-sided boxes. Having one of these would save the trouble of constructing
both a MaxPST and MinPST. But the presentiation is hard to follow in places and the paper's pseudocode is buggy.[^minmaxpst]

## Segment Tree

A segment tree stores information related to subintervals of a certain array. For example, a segment tree can be used to find the
sum of the elements in an arbitrary subinterval A(i..j) of an array A(0..n) in O(log n) time. Each node in the tree corresponds to a
subarray of A in such a way that the values we store in the nodes can be combined efficiently to determine the desired result for
arbitrary subarrays.

An excellent description of the idea is found at https://cp-algorithms.com/data_structures/segment_tree.html.

Generic code is provided in `SegmentTreeTemplate`. Concrete classes provide a handful of simple lambdas and constants to the
template class's initializer. Figuring out the details requires some knowledge of the internal mechanisms of a segment tree, for
which the link at cp-algorithms.com is very helpful. See the definitions of the concrete classes `MaxValSegmentTree` and
`IndexOfMaxValSegmentTree` for examples.

## Algorithms

The Algorithms submodule contains some algorithms using the data structures.

- `maximal_empty_rectangles(points)`
  - We are given a set P contained in a minimal box B = [x_min, x_max] x [y_min, y_max]. An _empty rectangle_ is a axis-parallel
    rectangle with positive area contained in B containing no element of P in its interior. A _maximal empty rectangle_ is an empty
    rectangle not properly contained in any other empty rectangle. This method yields each maximal empty rectangle in the form
    [left, right, bottom, top].
  - The algorithm is due to [[DMNS2013]](#references).

# C Extensions

As another learning process I have implemented several of these data structures as C extensions. The class names have a "C" prefixed
and they can be required like their pure Ruby versions. They have the same APIs as their Ruby cousins.

## Disjoint Union

A benchmark suggests that a long sequence of `unite` operations is about 3 times as fast with the `CDisjointUnion` as with
`DisjointUnion`.

The implementation uses the remarkable Convenient Containers library from Jackson Allan.[[Allan]](#references).

## Segment Tree

`CSegmentTreeTemplate` is the C implementation of the generic class. Concrete classes are built on top of this in Ruby, just as with
the pure Ruby `SegmentTreeTemplate` class.

A benchmark suggests that a long sequence of `max_on` operations against a max-val Segment Tree is about 4 times as fast with the C
version as with the Ruby version. I'm a bit suprised the improvment isn't larger, but we must remember that the C code must still
interact with the Ruby objects in the underlying data array, and must "combine" them, etc., by calling Ruby lambdas.

# References
- [Allan] Allan, J., _CC: Convenient Containers_, https://github.com/JacksonAllan/CC, retrieved 2023-02-01.
- [TvL1984] Tarjan, Robert E., van Leeuwen, J., _Worst-case Analysis of Set Union Algorithms_, Journal of the ACM, v31:2 (1984), pp 245–281.
- [EEK2017] Edelkamp, S., Elmasry, A., Katajainen, J., _Optimizing Binary Heaps_, Theory Comput Syst (2017), vol 61, pp 606-636, DOI 10.1007/s00224-017-9760-2.
- [McC1985] McCreight, E. M., _Priority Search Trees_, SIAM J. Comput., 14(2):257-276, 1985.
- [DMNS2011] De, M., Maheshwari, A., Nandy, S. C., Smid, M., _An In-Place Priority Search Tree_, 23rd Canadian Conference on Computational Geometry, 2011.
- [DMNS2013] De, M., Maheshwari, A., Nandy, S. C., Smid, M., _An In-Place Min-max Priority Search Tree_, Computational Geometry, v46 (2013), pp 310-327.

[^minmaxpst]: See the comments in the fragmentary class `MinMaxPrioritySearchTree` for further details.
