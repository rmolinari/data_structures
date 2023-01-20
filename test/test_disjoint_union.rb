require 'byebug'
require 'test/unit'

require 'data_structures_rmolinari'

DisjointUnion = DataStructuresRMolinari::DisjointUnion
CDisjointUnion = DataStructuresRMolinari::CDisjointUnion

class DisjointUnionTest < Test::Unit::TestCase
  def test_basic_operation
    check_basic_operation DisjointUnion.new(10)
  end

  def test_member_check
    check_member_check DisjointUnion.new(10)
  end

  def test_make_set
    check_make_set DisjointUnion.new
  end

  def test_basic_operation_in_c
    check_basic_operation CDisjointUnion.new(10)
  end

  def test_member_check_in_c
    check_member_check CDisjointUnion.new(10)
  end

  def test_make_set_in_c
    check_make_set CDisjointUnion.new
  end

  # Not actually a test, but a timing experiment. It belongs somewhere else, but the testing harness makes it easy to run it for now
  def test_timing_experiment
    size = Integer(ENV['test_size'] || 1_000_000)
    # First generate a long list of random numbers. This avoids the work of RNG clogging up timing information
    randoms = (0..(4 * size)).map { rand(size) }

    du = CDisjointUnion.new(size)
    (0..(size/2)).each do |idx|
      # unite two elements
      e1 = randoms[2 * idx]
      e2 = randoms[2 * idx + 1]
      next if e1 == e2

      du.unite(e1, e2)
    end

    #puts "Final subset count: #{du.subset_count}"
  end

  ########################################
  # Helpers

  private def check_basic_operation(du)
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

  private def check_member_check(du)
    assert_raise(Shared::DataError) do
      du.find(10)
    end
  end

  # Start with empty disjoint union
  private def check_make_set(du)
    raise "Expected empty disjoint union" unless du.subset_count.zero?
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
end
