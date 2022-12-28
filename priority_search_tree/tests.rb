require 'simplecov'
SimpleCov.start

require 'set'
require 'test/unit'
require 'timeout'

require_relative 'max_priority_search_tree'
require_relative 'minmax_priority_search_tree'

require 'byebug'

class PrioritySearchTreeTest < Test::Unit::TestCase
  INFINITY = Float::INFINITY

  def setup
    @size = (ENV['test_size'] || 100_000).to_i
    @pairs_by_x = raw_data(@size)
    @pairs_by_y = @pairs_by_x.sort_by(&:y)
  end

  ########################################
  # Tests for the (vanilla) MaxPST

  # Construct the data structure and validate that the key properties are actually satisifed.
  def test_pst_construction
    data = raw_data(@size)
    MaxPrioritySearchTree.new(data.shuffle, verify: true)
  end

  def test_pst_highest_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_highest_ne(x0, y0, max_pst)
    end
  end

  def test_pst_leftmost_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_leftmost_ne(x0, y0, max_pst)
    end
  end

  def test_pst_highest_3_sided
    100.times do
      x0 = rand(@size)
      x1 = x0 + 1 + rand(@size - x0)
      y0 = rand(@size)
      check_a_highest_3_sided(x0, x1, y0, max_pst)
    end
  end

  ########################################
  # Tests for the MinmaxPST
  def test_minmax_pst_construction
    data = raw_data(@size)
    # puts "Building the minmax PST tree..."
    MinmaxPrioritySearchTree.new(data.shuffle, verify: true)
  end

  # The tree code is buggy here. Let's try to find a small, reproducible error
  def test_minmax_pst_leftmost_ne
    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_a_leftmost_ne(x0, y0, minmax_pst)
    end
  end

  ########################################
  # Some regression tests on inputs found to be bad during testing

  private def check_one_case(klass, method, data, *method_params, expected_val)
    calculated_val = Timeout::timeout(timeout_time_s) do
      pst = klass.new(data.map { |x, y| Pair.new(x, y) })
      calculated_val = pst.send(method, *method_params)
    end
    assert_equal expected_val, calculated_val
  end

  def test_bad_inputs_for_max_highest_3_sided
    check_one = lambda do |data, *method_params, actual_highest|
      check_one_case(MaxPrioritySearchTree, :highest_3_sided, data, *method_params, actual_highest)
    end

    # Early versions of code couldn't even handle these!
    check_one.call([[1, 1]], 0, 1, 0, Pair.new(1, 1))

    check_one.call(
      [[4,5], [1,4], [5,2], [2,1], [3,3]],
      2, 3, 2,
      Pair.new(3, 3)
    )

    check_one.call(
      [[8,8], [1,7], [6,5], [2,6], [4,3], [5,1], [7,2], [3,4]],
      3, 5, 0,
      Pair.new(3, 4)
    )

    check_one.call(
      [[7,8], [1,5], [5,7], [2,3], [4,1], [6,6], [8,4], [3,2]],
      3, 4, 1,
      Pair.new(3, 2)
    )
  end

  def test_bad_inputs_for_minmax_leftmost_ne
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MinmaxPrioritySearchTree, :leftmost_ne, data, *method_params, actual_leftmost)
    end
    # Some inputs on which the code was found to be buggy
    check_one.call(
      [[4,10], [2,1], [8,2], [3,5], [7,7], [9,9], [10,8], [1,4], [5,3], [6,6]],
      5, 6,
      Pair.new(6, 6)
    )

    check_one.call(
      [
        [20,32], [1,1], [17,2], [2,31], [15,26], [24,30], [30,29], [5,4], [9,10], [11,18], [16,3], [19,8], [22,11], [28,5],
        [31,7], [3,21], [6,9], [7,22], [8,28], [10,25], [12,23], [13,19], [14,6], [18,27], [21,13], [23,14], [25,24], [26,12],
        [27,17], [29,20], [32,16], [4,15]
      ],
      4, 11,
      Pair.new(4, 15)
    )

    data = [[10,11], [5,2], [11,1], [2,8], [4,9], [8,10], [9,7], [1,5], [3,3], [6,6], [7,4]]
    check_one.call(data, 3, 9, Pair.new(4, 9))
  end

  def test_bad_inputs_for_max_enumerate_3_sided
    check_one = lambda do |data, *method_params, actual_vals|
      actual_set = Set.new(actual_vals.map { |x, y| Pair.new(x, y) })
      check_one_case(MaxPrioritySearchTree, :enumerate_3_sided, data, *method_params, actual_set)
    end

    # These had timeouts in early code
    check_one.call([[1,1]],                                    0, 1, 0, [[1, 1]])
    check_one.call([[2,2], [1,1]],                             0, 1, 1, [[1, 1]])
    check_one.call([[2,6], [3,5], [5,3], [1,4], [4,2], [6,1]], 3, 5, 5, [[3, 5]])
    check_one.call([[5,10], [7,8], [10,9], [2,7], [6,4], [8,6], [9,5], [1,1], [3,2], [4,3]], 5, 6, 0, [[6, 4], [5, 10]])

    # These ones didn't time out, but returned bad values
    check_one.call([[2,3], [1,1], [3,2]],                             0, 1, 0, [[1, 1]])
    check_one.call([[7,7], [1,5], [4,6], [2,2], [3,1], [5,4], [6,3]], 5, 6, 3, [[5,4], [6, 3]])
    check_one.call(
      [[8,12], [6,11], [10,10], [2,7], [7,8], [11,9], [12,1], [1,5], [3,6], [4,2], [5,3], [9,4]],
      3, 10, 0,
      [[8, 12], [10, 10], [6, 11], [9, 4], [5, 3], [3, 6], [4, 2], [7, 8]]
    )
    check_one.call(
      [[4,14], [5,13], [13,12], [2,11], [8,9], [10,10], [14,8], [1,4], [3,3], [6,7], [7,1], [9,5], [11,6], [12,2]],
      6, 13, 0,
      [[6, 7], [11, 6], [10, 10], [8, 9], [12, 2], [9, 5], [7, 1], [13, 12]]
    )
  end

  ########################################
  # Some quasi-tests that search for inputs that lead to assertion failures.
  #
  # They are all no-ops unless the environment variable find_bad is set

  BAD_INPUT_SEARCH_ATTEMPT_LIMIT = 1_000

  def test_minmax_find_bad_input_for_leftmost_ne
    search_for_bad_inputs(MinmaxPrioritySearchTree, :leftmost_ne) do |pairs|
      x0 = rand(@size)
      y0 = rand(@size)
      actual_leftmost = pairs.select { |p| p.x >= x0 && p.y >= y0 }.min_by(&:x) || Pair.new(INFINITY, INFINITY)

      [[x0, y0], actual_leftmost]
    end
  end

  def test_max_find_bad_input_for_highest_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :highest_3_sided) do |pairs|
      x0 = rand(@size)
      x1 = x0 + 1 + rand(@size - x0)
      y0 = rand(@size)
      actual_highest = pairs.select { |p| x0 <= p.x && p.x <= x1 && p.y >= y0 }.max_by(&:y) || Pair.new(INFINITY, -INFINITY)

      [[x0, x1, y0], actual_highest]
    end
  end

  def test_max_find_bad_input_for_enumerate_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :enumerate_3_sided) do |pairs|
      x0 = rand(@size)
      x1 = x0 + 1 + rand(@size - x0)
      y0 = rand(@size)
      actual_set = Set.new(pairs.select { |p| x0 <= p.x && p.x <= x1 && p.y >= y0 } || [])

      [[x0, x1, y0], actual_set]
    end
  end

  # Search for a set of bad input that causes klass#method to return the wrong value.
  #
  # If we find such data then output the details to stdout and fail an assertion. Otherwise return true.
  #
  # We try BAD_INPUT_SEARCH_ATTEMPT_LIMIT times. On each attempt we generate a list of (x,y) pairs and yield it to a block from
  # which we should receive a pair
  #
  #    [method_params, expected_value]
  #
  # where
  #  - method_params is an array of the method parameters to pass to #method on the klass instance
  #  - expected_value is the value the method should return
  #
  # It is a no-op unless the environment variable find_bad is set
  private def search_for_bad_inputs(klass, method)
    return unless find_bad_inputs?

    BAD_INPUT_SEARCH_ATTEMPT_LIMIT.times do
      pairs = raw_data(@size).shuffle
      method_params, expected_value = yield(pairs)
      pst = klass.new(pairs)

      timeout = false
      begin
        calculated_value = Timeout::timeout(timeout_time_s) {
          pst.send(method, *method_params)
        }
      rescue Timeout::Error
        puts "*\n*\n"
        puts "* >>>>>>>TIMEOUT<<<<<<<<"
        puts "*\n*\n"
        timeout = true
      end

      next unless timeout || expected_value != calculated_value

      puts "params = [#{method_params.join(', ')}]"
      pair_data = pairs.map { |p| "[#{p.x},#{p.y}]" }.join(', ')
      puts "data = [#{pair_data}]"

      assert_equal expected_value, calculated_value
    end
    puts "No bad data found for #{klass}##{method}"
  end

  private def find_bad_inputs?
    ENV['find_bad']
  end

  private def timeout_time_s
    ENV['debug'] ? 1e10 : 0.5
  end

  ########################################
  # Helpers

  private def max_pst
    @max_pst ||= MaxPrioritySearchTree.new(@pairs_by_x.shuffle)
  end

  private def minmax_pst
    @minmax_pst ||= MinmaxPrioritySearchTree.new(@pairs_by_x.shuffle)
  end

  private def check_a_highest_ne(x0, y0, pst)
    # puts "Calculating highest_ne(#{x0}, #{y0})"
    highest = ne_quadrant(x0, y0).max_by(&:y) || Pair.new(INFINITY, -INFINITY)
    calc_highest = pst.highest_ne(x0, y0)

    assert_equal highest, calc_highest
  end

  private def check_a_leftmost_ne(x0, y0, pst)
    # puts "Calculating leftmost_ne(#{x0}, #{y0})"
    leftmost = ne_quadrant(x0, y0).min_by(&:x) || Pair.new(INFINITY, INFINITY)
    calc_leftmost = pst.leftmost_ne(x0, y0)

    assert_equal leftmost, calc_leftmost
  end

  private def check_a_highest_3_sided(x0, x1, y0, pst)
    highest = ne_quadrant(x0, y0).reject { |pair| pair.x > x1 }.max_by(&:y) || Pair.new(INFINITY, -INFINITY)
    calc_highest = pst.highest_3_sided(x0, x1, y0)

    assert_equal highest, calc_highest
  end

  private def raw_data(size)
    list = (1..size).to_a
    list.zip(list.shuffle).map { Pair.new(*_1) }
  end

  # Points (x,y) in @data with x >= x0
  private def rightward_points(x0)
    first_idx = @pairs_by_x.bsearch_index { |v| v.x >= x0 }
    @pairs_by_x[first_idx..]
  end

  private def upward_points(y0)
    first_idx = @pairs_by_y.bsearch_index { |v| v.y >= y0 }
    @pairs_by_y[first_idx..]
  end

  private def ne_quadrant(x0, y0)
    if x0 > y0
      rightward_points(x0).select { |pair| pair.y >= y0 }
    else
      upward_points(y0).select { |pair| pair.x >= x0 }
    end
  end
end
