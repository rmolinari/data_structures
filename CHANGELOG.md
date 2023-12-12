# Changelog

## [Unreleased]

## [0.5.4] 2023-12-12

(Unfortunately this note was added long after the changes were made and my memory of the changes is poor.)

- SegmentTree
  - Sum version is provided
- PrioritySearchTree
  - Open regions

- Some bug fixes
- Some refactoring of test cases

## [0.5.1] - [0.5.3]

- Releases to fix some bad gemspec data.

## [0.5.0] 2023-02-03

- SegmentTree
  - Reorganize the code into a SegmentTree submodule.
  - Provide a conveniece method for getting concrete instances.

- README.md
  - Add some simple example code for the data types.

## [0.4.4] 2023-02-02

- Disjoint Union
  - C extension: use Convenient Containers rather than my janky Dynamic Array attempt.

- Segment Tree
  - Add a C implementation as CSegmentTreeTemplate.

## [0.4.3] 2023-01-27

- Fix bad directive in Rakefile for DisjointUnion C extension

## [0.4.2] 2023-01-26

### Added

- MinPrioritySearchTree added
  - it's a thin layer on top of a MaxPrioritySearchTree with negated y values.

- MaxPrioritySearchTree
  - A "dynamic" constructor option now allows deletion of the "top" (root) node. This is useful in certain algorithms.

- DisjointUnion
  - Added a proof-of-concept implementation in C, which is about twice as fast.

- Algorithms
  - Implement the Maximal Empty Rectangle algorithm of De et al. It uses a dynamic MaxPST.

## [0.4.1] 2023-01-12

- Update this file for the gem (though I forgot to add this comment first!)

## [0.4.0] 2023-01-12

### Changed

- MaxPrioritySearchTree
  - Duplicate y values are now allowed. Ties are broken with a preference for smaller values of x.
  - Method names have changed
    - Instead of "highest", "leftmost", "rightmost" we use "largest_y", "smallest_x", "largest_x"
    - For example, `highest_ne` is now `largest_y_in_nw`
- DisjointUnion
  - the size argument to initializer is optional. The default value is 0.
  - elements can be added to the "universe" of known values with `make_set`

### Removed
- MinmaxPrioritySearchTree is no longer available
  - it was only a partial implementation anyway

## [0.3.0] 2023-01-06

### Added

- Start this file
- `Heap` can be constructed as "non-addressable"
  - `update` is not possible but duplicates can be inserted and overall performance is a little better.

### Changed

- `LogicError` gets a subclassed `InternalLogicError` for issues inside the library.
- `Shared::Pair` becomes `Shared::Point`
  - this doesn't change the API of `MaxPrioritySearchTree` because of ducktyping. But client code (of which there is none) might be
    using the `Pair` name.
