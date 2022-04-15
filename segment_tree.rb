# Experimental implementation of a segment tree, to see if I understand what is going on.
#
# Good description: https://cp-algorithms.com/data_structures/segment_tree.html


# We represent values in an interval (0...size). All values start out at zero
#
# Three mutations are provided:
#
#    set(l, r, v): all values in the range l...r are set to v
#    add(l, r, d): all values in the range l...r are incremented by d (which can be negative)
#    sub(l, r, d, support): all values in the range l...r are reduced by d but do not get any smaller than support (which defaults
#                  to zero)
class SegmentTree
  attr_reader :size

  def initialize(size, initial_value: 0)
    @size = size

    @fixed_value = [nil, initial_value]  # nothing is stored at 0. The root of the tree is at index 1

    @root = 1
  end

  # The value at index idx
  def [](idx)
    value_at(idx, @root, 0, @size)
  end

  # Elements in the interval tl...tr are now v
  def set(tl, tr, value)
    set_value_on = lambda do |node, l, r|
      if tl <= l  && r <= tr
        @fixed_value[node] = value
      else
        raise "Bad interval (#{l}...#{r}) trying to set values on (#{tl}...#{tr})" if r - l == 1

        if @fixed_value[node]
          push(node)
        end

        mid = middle(l, r)
        if tr <= mid
          set_value_on.call(left_child(node), l, mid)
        elsif mid <= tl
          set_value_on.call(right_child(node), mid, r)
        else
          set_value_on.call(left_child(node), l, mid)
          set_value_on.call(right_child(node), mid, r)
        end
      end
    end

    set_value_on.call(@root, 0, @size)
  end

  private

  # Push the fixed value from node down to its children
  def push(node)
    v = @fixed_value[node]
    @fixed_value[left_child(node)] = v
    @fixed_value[right_child(node)] = v

    @fixed_value[node] = nil
  end

  def value_at(idx, node, l, r)
    if r - l == 1
      raise "Looking for value at #{idx} but have stumbled on the leaf for #{l}" unless l == idx

      @fixed_value[node]
    elsif @fixed_value[node]
      @fixed_value[node]
    else
      mid = middle(l, r)
      if idx < mid
        value_at(idx, left_child(node), l, mid)
      else
        value_at(idx, right_child(node), mid, r)
      end
    end
  end

  def left_child(node)
    2 * node
  end

  def right_child(node)
    2 * node + 1
  end

  def parent(node)
    node / 2
  end

  def middle(l, r)
    (r + l) / 2
  end

end
