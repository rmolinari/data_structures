require 'forwardable'

require_relative 'data_structures_rmolinari/shared'

# A namespace to hold the provided classes. We want to avoid polluting the global namespace with names like "Heap"
module DataStructuresRMolinari
  # A struct responding to +.x+ and +.y+.
  Point = Shared::Point
end

# These define classes inside module DataStructuresRMolinari
require_relative 'data_structures_rmolinari/algorithms'

require_relative 'data_structures_rmolinari/disjoint_union'
require_relative 'data_structures_rmolinari/c_disjoint_union' # version as a C extension

require_relative 'data_structures_rmolinari/segment_tree'

require_relative 'data_structures_rmolinari/heap'
require_relative 'data_structures_rmolinari/max_priority_search_tree'
require_relative 'data_structures_rmolinari/min_priority_search_tree'

module DataStructuresRMolinari
  # Add things here if needed
end
