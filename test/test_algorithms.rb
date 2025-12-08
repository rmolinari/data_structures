require 'byebug'
require 'test/unit'

require 'data_structures_rmolinari'

class AlgorithmTest < Test::Unit::TestCase
  Point = Shared::Point
  Algorithms = DataStructuresRMolinari::Algorithms

  ########################################
  # Maximal Empty Rectangle (MER)

  def test_simple_mer_cases
    check_mer_case([[0,0]], [])
    check_mer_case([[0,0], [1,1]], [1])
    check_mer_case([[0,0], [0.5, 0.5], [1, 1]], [0.5, 0.5, 0.5, 0.5])
    check_mer_case(
      [[0,0], [Rational(4,5), Rational(1,2)], [1, 1]],
      [Rational(4,5), Rational(1,5), Rational(1,2), Rational(1,2)]
    )
  end

  def test_top_k
    check_first_k_case([1, 2, 3, 4, 5], 3, [1, 2, 3])
    check_first_k_case([1, 2, 3, 4, 5].reverse, 3, [1, 2, 3])
    check_first_k_case([1, 7, 8, 3, 4, 2, 9, 4], 5, [1, 2, 3, 4, 4])
    check_first_k_case([7, 6, 5, 1, 22], 5, [1, 5, 6, 7, 22])

    # Try some with a block that gives the sort key
    check_first_k_case(%w[apple banana pear raspberry], 2, %w[pear apple]) { |s| s.length }
    check_first_k_case([[1,1], [2,2], [1,2], [-2, -3]], 3, [[1,1], [1,2], [2,2]]) { |x, y| x * x + y * y }
  end

  # Because its easy, for now check that we get the expected set of MER areas
  private def check_mer_case(points, expected_areas)
    points.map! { |pt| pt.is_a?(Point) ? pt : Point.new(*pt) }

    areas = []
    Algorithms.maximal_empty_rectangles(points) do |left, right, bottom, top|
      areas << (right - left) * (top - bottom)
    end

    assert_equal expected_areas.sort, areas.sort
  end

  private def check_first_k_case(values, k, expected, &block)
    result = if block_given?
      Algorithms.first_k(values, k, &block)
    else
      Algorithms.first_k(values, k)
    end

    assert_equal expected, result
  end
end
