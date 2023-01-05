# Data Structures

This is a small collection of Ruby data structures that I have implemented for my own sake. Implementing the code for a data
structure is almost always more educational than simply reading about it and is usually fun.

These implementations are not particularly clever. They are based on the expository descriptions and pseudo-code I found as I read
about each structure and so are unlikely to be as fast as possible.

The code is available in gem form as `data_structures_rmolinari`: https://rubygems.org/gems/data_structures_rmolinari.

## Usage

The right way to organize the code is not obvious to me. For now the data structures are all defined in the module
`DataStructuresRMolinari` to avoid polluting the global namespace.

Example usage after the gem is installed:
```
require 'data_structures_rmolinari`

MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
Pair = DataStructuresRMolinari::Pair

pst = MaxPrioritySearchTree.new([Pair.new(1, 1)])
puts pst.highest_ne(0, 0)
```

## Implementations

### Disjoint Union

We represent the set S(n) = {0, 1, ..., n} as the disjoint union of subsets. Alternatively, we represent a partition of S(n). The data
structure provides very efficient implementation of the two key operations
- `unite(e, f)`, which merges the subsets containing e and f; and
- `find(e)`, which returns the canonical representative of the subset containing e. Two elements e and f are in the same subset
  exactly when `find(e) == find(f)`.

### Heap

A binary heap with an `update` method, suitable for use as a priority queue. See https://en.wikipedia.org/wiki/Binary_heap and
Edelkamp et al.

### Priority Search Tree

A PST stores a set of two-dimensional points in a way that allows certain queries to be answered efficiently. The implementation is
in `MaxPrioritySearchTree`.

See the papers McCreight (1985) and De et al (2011).

### Segment Tree

Segment trees store information related to subintervals of a certain array. For example, they can be used to find the sum of the
elements in an arbitrary subinterval A[i..j] of an array A[0..n] in O(log n) time.

An excellent description of the idea is found at https://cp-algorithms.com/data_structures/segment_tree.html.

There is a generic implementation, `GenericSegmentTree`, and a concrete class `MaxValSegmentTree`.

## References
- Edelkamp, S., Elmasry, A., Katajainen, J., _Optimizing Binary Heaps_, Theory Comput Syst (2017), vol 61, pp 606-636, DOI 10.1007/s00224-017-9760-2
- E.M. McCreight, E.M., _Priority search trees_, SIAM J. Comput., 14(2):257-276, 1985.
- De, M., Maheshwari A.,, Nandy, S. C., Smid, M., _An In-Place Priority Search Tree_, 23rd Canadian Conference on Computational Geometry, 2011
