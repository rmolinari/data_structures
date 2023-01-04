# Some odds and ends shared by other classes
module Shared
  INFINITY = Float::INFINITY

  Pair = Struct.new(:x, :y)

  class LogicError < StandardError; end

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

    # i has no children
    private def leaf?(i)
      i > @last_non_leaf
    end

    # i has exactly one child (the left)
    private def one_child?(i)
      i == @parent_of_one_child
    end

    # i has two children
    private def two_children?(i)
      i <= @last_parent_of_two_children
    end

    # i is the left child of its parent.
    private def left_child?(i)
      (i & 1).zero?
    end
  end
end
