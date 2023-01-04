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
    @increments = [nil, 0] # "add k to values on (l...r)"

    @root = 1
  end

  # The value at index idx
  def [](idx)
    value_at(idx, @root, 0, @size)
  end

  # Elements in the interval tl...tr now take value v
  def set(tl, tr, value)
    set_value_on = lambda do |node, l, r|
      if tl <= l && r <= tr
        @fixed_value[node] = value
      else
        raise "Bad interval (#{l}...#{r}) trying to set values on (#{tl}...#{tr})" if r - l == 1

        push(node, @fixed_value)

        mid = middle(l, r)
        set_value_on.call(left_child(node), l, mid) if tl < mid
        set_value_on.call(right_child(node), mid, r) if mid < tr
      end
    end

    set_value_on.call(@root, 0, @size)
  end

  # Elements in the interval tl...tr have values incremented by delta
  def add(tl, tr, delta)
    increase_value_on = lambda do |node, l, r|
      if tl <= l && r <= tr
        @increments[node] += delta
      else
        raise "Bad interval (#{l}...#{r}) trying to increment values on (#{tl}...#{tr})" if r - l == 1

        push(node, @increments)

        mid = middle(l, r)
        increase_value_on.call(left_child(node), l, mid) if tl < mid
        increase_value.call(right_child(node), mid, r) if mid < tr
      end
    end

    increase_value_on.call(@root, 0, @size)
  end

  private

  # Push the value, if any, from node down to its children
  def push(node, values)
    v = values[node]
    return unless v

    values[left_child(node)] = v
    values[right_child(node)] = v

    values[node] = nil
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
