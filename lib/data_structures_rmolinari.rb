require_relative 'data_structures_rmolinari/shared'
require_relative 'data_structures_rmolinari/max_priority_search_tree_internal'
require_relative 'data_structures_rmolinari/minmax_priority_search_tree_internal'

module DataStructuresRMolinari
  Pair = Shared::Pair

  MaxPrioritySearchTree = MaxPrioritySearchTreeInternal
  MinmaxPrioritySearchTree = MinmaxPrioritySearchTreeInternal
end
