require 'byebug'
require 'test/unit'

require 'data_structures_rmolinari'

DisjointUnion = DataStructuresRMolinari::DisjointUnion
CDisjointUnion = DataStructuresRMolinari::CDisjointUnion

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

  def test_make_set
    du = DisjointUnion.new # empty

    assert_raise(Shared::DataError) do
      du.find(0)
    end

    du.make_set(0)
    assert_equal 0, du.find(0)

    # Try non-contiguous
    du.make_set(10)
    assert_equal 0, du.find(0)
    assert_equal 2, du.subset_count

    du.unite(0, 10)
    assert_equal 1, du.subset_count
    assert_equal du.find(0), du.find(10)

    assert_raise(Shared::DataError) do
      du.find(2)
    end
  end

  # Experimental: Try out the version written in C
  def test_c_extension
    empty_one = CDisjointUnion.new
    assert_equal 0, empty_one.subset_count
    empty_one.make_set(0)
    assert_equal 1, empty_one.subset_count
    assert_equal 0, empty_one.find(0)

    assert_raise(ArgumentError) do
      empty_one.make_set(0)
    end

    tenner = CDisjointUnion.new(10)
    assert_equal 10, tenner.subset_count
    tenner.make_set(10)
    assert_equal 11, tenner.subset_count
    (0..10).each do |elt|
      assert_equal elt, tenner.find(elt)
    end
    tenner.unite(0, 1)
    assert_equal 10, tenner.subset_count
  end
end
