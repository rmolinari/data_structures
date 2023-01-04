# Data Structures

This is a small collection of Ruby data structures that I have implemented for my own sake. Implementing the code for a data
structure is almost always more educational than simply reading about it and is usually fun.

These implementations are not particularly clever and are probably slow. They are based on the expository descriptions and
pseudo-code I found as I read about each structure and so are unlikely to be as fast as possible.

Documentation is a work in progress.

The code will soon be available as a Ruby gem.

## Usage

The right way to organize the code is not obvious to me. For now the data structures are all defined in a module to avoid polluting
the global namespace. Once it is published as a gem the usage will look like this:
```
require 'data_structures_rmolinari`

MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
Pair = DataStructuresRMolinari::Pair

pst = MaxPrioritySearchTree.new([Pair.new(1, 1)])
puts pts.highest_ne(0, 0)
```

## Priority Search Tree

Store a set of two-dimensional points in a way that allows certain queries to be answered efficiently. See McCreight and De et al.

## References
- E.M. McCreight, _Priority search trees_, SIAM J. Comput., 14(2):257-276, 1985.
- M. De, A. Maheshwari, S. C. Nandy, M. Smid, _An In-Place Priority Search Tree_, 23rd Canadian Conference on Computational Geometry, 2011
