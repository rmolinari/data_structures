# @private
#
# Helpers for +find_leftmost_by_prefix+.
module DataStructuresRMolinari::SegmentTree::FindLeftmostByPrefix
  module_function

  def normalize_compare(compare)
    case compare
    when :ge then ->(agg, t) { agg >= t }
    when :le then ->(agg, t) { agg <= t }
    when Proc then compare
    else
      raise ArgumentError, "compare must be :ge, :le, or a Proc (got #{compare.inspect})"
    end
  end

  def normalize_compare_symbol(compare)
    case compare
    when :ge, :le then compare
    when Proc
      raise ArgumentError, 'custom compare Proc is only supported on SegmentTreeTemplate (:ruby), not CSegmentTreeTemplate'
    else
      raise ArgumentError, "compare must be :ge or :le for C templates (got #{compare.inspect})"
    end
  end
end
