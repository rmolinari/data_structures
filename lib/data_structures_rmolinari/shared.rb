# Some odds and ends shared by other classes
module Shared
  # Infinity without having to put a +Float::+ prefix every time
  INFINITY = Float::INFINITY

  # An (x, y) coordinate pair.
  Point = Struct.new(:x, :y) do
    def to_s
      "[#{x}, #{y}]"
    end
  end

  # @private

  # Used for errors related to logic errors in client code
  class LogicError < StandardError; end
  # Used for errors related to logic errors in library code
  class InternalLogicError < LogicError; end

  # Used for errors related to data, such as duplicated elements where they must be distinct.
  class DataError < StandardError; end

  # @private
  #
  # Provide simple arithmetic for an implied binary tree stored in an array, with the root at 1
  module BinaryTreeArithmetic
    # First element and root of the tree structure
    private def root
      1
    end

    # The parent of node i
    private def parent(i)
      i >> 1
    end

    # The left child of node i
    private def left(i)
      i << 1
    end

    # The right child of node i
    private def right(i)
      1 + (i << 1)
    end

    # The level in the tree of node i. The root is at level 0.
    private def level(i)
      l = 0
      while i > root
        i >>= 1
        l += 1
      end
      l
    end

    # i is the left child of its parent.
    private def left_child?(i)
      (i & 1).zero?
    end
  end

  # Simple O(n) check for duplicates in an enumerable.
  #
  # It may be worse than O(n), depending on how close to constant set insertion is.
  #
  # @param enum the enumerable to check for duplicates
  # @param by a method to call on each element of enum before checking. The results of these methods are checked for
  #        duplication. When nil we don't call anything and just use the elements themselves.
  def contains_duplicates?(enum, by: nil)
    seen = Set.new
    enum.any? do |v|
      v = v.send(by) if by
      !seen.add?(v)
    end
  end
end
