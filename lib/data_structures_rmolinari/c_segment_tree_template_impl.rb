require 'must_be'

require_relative 'shared'
require_relative 'c_segment_tree_template'

# The underlying functionality of the Segment Tree data type, implemented in C as a Ruby extension.
#
# See SegmentTreeTemplate for more information.
class DataStructuresRMolinari::SegmentTree::CSegmentTreeTemplate
  # (see SegmentTreeTemplate::initialize)
  #
  # Either pass the generic lambda-based configuration (+combine+, +single_cell_array_val+, +size+, +identity+), or pass a Fixnum
  # fast-path configuration (+data+, +fixnum_op+, +identity+) where +data+ is an Array of Fixnums and +fixnum_op+ is one of
  # +:max+, +:min+, +:sum+, +:product+.
  def initialize(combine: nil, single_cell_array_val: nil, size: nil, identity: nil, data: nil, fixnum_op: nil)
    if fixnum_op
      unless combine.nil? && single_cell_array_val.nil?
        raise ArgumentError, 'combine and single_cell_array_val must not be passed when using fixnum_op'
      end

      fixnum_op.must_be_in [:max, :min, :sum, :product]
      raise ArgumentError, 'data must be an Array for fixnum fast path' unless data.is_a?(Array)
      raise ArgumentError, 'size must match data.length' if !size.nil? && size != data.size

      c_initialize_fixnum(data, data.size, fixnum_op, identity)
    else
      raise ArgumentError, 'combine is required unless fixnum_op is set' if combine.nil?
      raise ArgumentError, 'single_cell_array_val is required unless fixnum_op is set' if single_cell_array_val.nil?
      raise ArgumentError, 'size is required unless fixnum_op is set' if size.nil?

      c_initialize(combine, single_cell_array_val, size, identity)
    end
  end
end
