require 'must_be'

require_relative 'shared'
require_relative 'c_segment_tree_template'

# The underlying functionality of the Segment Tree data type, implemented in C as a Ruby extension.
#
# See SegmentTreeTemplate for more information.
class DataStructuresRMolinari::CSegmentTreeTemplate
  # (see SegmentTreeTemplate::initialize)
  def initialize(combine:, single_cell_array_val:, size:, identity:)
    # having sorted out the keyword arguments, pass them more easily to the C layer.
    c_initialize(combine, single_cell_array_val, size, identity)
  end
end
