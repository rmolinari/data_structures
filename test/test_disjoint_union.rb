require 'byebug'
require 'test/unit'

require 'data_structures_rmolinari'

DisjointUnion = DataStructuresRMolinari::DisjointUnion

class DisjointUnionTest < Test::Unit::TestCase
  def test_basic_operation
    du = DisjointUnion.new(10)

    assert_equal 10, du.subset_count # all in separate sets

    du.unite(0, 2)

    assert_equal 9, du.subset_count
    assert_equal du.find(0), du.find(2)

    du.unite(2, 4)
    du.unite(4, 6)
    du.unite(6, 8)

    assert_equal 1, [0, 2, 4, 6, 8].map{ du.find _1 }.uniq.size
    assert_equal 5, [1, 3, 5, 7, 9].map{ du.find _1 }.uniq.size
  end

  def test_member_check
    du = DisjointUnion.new(10)
    assert_raise(Shared::DataError) do
      du.find(10)
    end
  end
end
