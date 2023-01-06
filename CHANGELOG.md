# Changelog

## [Unreleased]

### Added

- Start this file
- `Heap` can be constructed as "non-addressable": `update` is not available but duplicates can be inserted.

### Changed

- `LogicError` gets a subclassed `InternalLogicError` for issues inside the library.
- `Shared::Pair` becomes `Shared::Point`
  - this doesn't change the API of `MaxPrioritySearchTree` because of ducktyping. But client code (of which there is none) might be using the `Pair` name.
