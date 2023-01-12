# Changelog

## [Unreleased]

### Changed

- MaxPrioritySearchTree allows duplicate y values. Ties are broken with a preference for smaller values of x.
- DisjointUnion
  - size argument to initializer is optional. The default value is 0.
  - elements can be added to the "universe" of known values with +make_set+

### Removed
- MinmaxPrioritySearchTree is no longer available

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
