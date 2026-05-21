require 'must_be'

require_relative 'shared'
require_relative 'find_leftmost_by_prefix'
require_relative 'c_segment_tree_template'

# The underlying functionality of the Segment Tree data type, implemented in C as a Ruby extension.
#
# See SegmentTreeTemplate for more information.
class DataStructuresRMolinari::SegmentTree::CSegmentTreeTemplate
  # (see SegmentTreeTemplate::initialize)
  #
  # Either pass the generic lambda-based configuration (+combine+, +single_cell_array_val+, +size+, +identity+), or pass a Fixnum
  # fast-path configuration (+data+, +fixnum_op+, +identity+) where +data+ is an Array of Fixnums and +fixnum_op+ is one of
  # +:max+, +:sum+, or +:product+.
  def initialize(combine: nil, single_cell_array_val: nil, size: nil, identity: nil, data: nil, fixnum_op: nil)
    if fixnum_op
      unless combine.nil? && single_cell_array_val.nil?
        raise ArgumentError, 'combine and single_cell_array_val must not be passed when using fixnum_op'
      end

      fixnum_op.must_be_in [:max, :sum, :product]
      raise ArgumentError, 'data must be an Array for fixnum fast path' unless data.is_a?(Array)
      raise ArgumentError, 'size must match data.length' if !size.nil? && size != data.size

      @fixnum_op = fixnum_op
      @size = data.size
      c_initialize_fixnum(data, data.size, fixnum_op, identity)
    else
      raise ArgumentError, 'combine is required unless fixnum_op is set' if combine.nil?
      raise ArgumentError, 'single_cell_array_val is required unless fixnum_op is set' if single_cell_array_val.nil?
      raise ArgumentError, 'size is required unless fixnum_op is set' if size.nil?

      @fixnum_op = nil
      @size = size
      @combine = combine
      @single_cell_array_val = single_cell_array_val
      @identity = identity
      c_initialize(combine, single_cell_array_val, size, identity)
    end
  end

  # (see SegmentTreeTemplate#find_leftmost_by_prefix)
  #
  # Fixnum fast path uses native aggregates. Generic (lambda) templates use a C walk that calls +combine+ per level.
  # Custom +compare+ Procs are not supported; use SegmentTreeTemplate (:ruby) instead.
  def find_leftmost_by_prefix(query_l, query_r, origin: 0, threshold:, compare: :ge)
    raise ArgumentError, 'origin must be 0' unless origin == 0

    if compare.is_a?(Proc)
      if @fixnum_op
        raise ArgumentError,
              'custom compare Proc is not supported on the C fixnum fast path; use lang: :ruby or compare: :ge / :le'
      end

      return ruby_template_for_find_leftmost.find_leftmost_by_prefix(
        query_l, query_r, origin:, threshold:, compare:
      )
    end

      compare_sym = SegmentTree::FindLeftmostByPrefix.normalize_compare_symbol(compare)
    c_find_leftmost_by_prefix(query_l, query_r, threshold, compare_sym)
  end

  private def ruby_template_for_find_leftmost
    raise ArgumentError, 'ruby template fallback requires generic (lambda) C initialization' if @fixnum_op

    DataStructuresRMolinari::SegmentTree::SegmentTreeTemplate.new(
      combine:               @combine,
      single_cell_array_val: @single_cell_array_val,
      size:                  @size,
      identity:              @identity
    )
  end
end
