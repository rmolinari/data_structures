require 'byebug'
require 'test/unit'

require 'data_structures_rmolinari'

Point = Shared::Point
Algorithms = DataStructuresRMolinari::Algorithms

class AlgorithmTest < Test::Unit::TestCase
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

  # Because its easy, for now check that we get the expected set of MER areas
  private def check_mer_case(points, expected_areas)
    points.map! { |pt| pt.is_a?(Point) ? pt : Point.new(*pt) }

    areas = []
    Algorithms.maximal_empty_rectangles(points) do |left, right, bottom, top|
      areas << (right - left) * (top - bottom)
    end

    assert_equal expected_areas.sort, areas.sort
  end
end
