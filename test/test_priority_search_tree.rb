require 'byebug'
require 'must_be'
require 'set'
require 'test/unit'
require 'timeout'
require 'ruby-prof'

require 'data_structures_rmolinari'

class PrioritySearchTreeTest < Test::Unit::TestCase
  Point = Shared::Point
  InternalLogicError = Shared::InternalLogicError

  MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
  MinPrioritySearchTree = DataStructuresRMolinari::MinPrioritySearchTree

  INFINITY = Shared::INFINITY

  def setup
    @size = (ENV['test_size'] || 10_000).to_i
    @common_raw_data = raw_data(@size)
  end

  # A pair of a real PST and a corresponding simple one that we can use to check the real one against.
  class PSTPair
    attr_reader :pst, :simple_pst

    def initialize(pst, simple_pst)
      @pst = pst
      @simple_pst = simple_pst
    end

    def empty?
      @pst.empty?
    end

    def delete_top!
      top = @pst.delete_top!
      @simple_pst.delete!(top)
    end
  end

  ########################################
  # Tests for the (vanilla) MaxPST
  #
  # Note that the time these tests take to run is dominated by the work we do in the test code to determine what the correct answer
  # is. Over 99.5% of the time in a typical test is taken up by the code determining what the expected result is.
  #
  # Having dumb code work out the correct answer is the right thing to do, but it means there are some slow tests! The relative
  # slowness of the brute-force approach is a good indication of how much time the PST datastructure saves us.

  # Construct the data structure and validate that the key properties are actually satisifed.
  def test_pst_construction
    data = raw_data(@size)
    MaxPrioritySearchTree.new(data.shuffle, verify: true)
  end

  def test_duplicate_coordinate_checks
    # duplicate x values
    assert_raise(Shared::DataError) do
      MaxPrioritySearchTree.new([Point.new(0, 0), Point.new(0, 1)])
    end
  end

  def test_max_pst_quadrant_calls
    %i[largest_y_in_ne largest_y_in_nw smallest_x_in_ne largest_x_in_nw].each do |method|
      [true, false].each do |open|
        check_quadrant_calc_pair(max_pst_pair, method, open: open)
      end
    end
  end

  def test_max_pst_3_sided_calls
    [true, false].each do |open|
      check_3_sided_calc_pair(max_pst_pair, :largest_y_in_3_sided, open:)
    end
  end

  def test_max_pst_enumerate_3_sided_calls
    [true, false].each do |open|
      [true, false].each do |enumerate_via_block|
        check_3_sided_calc_pair(max_pst_pair, :enumerate_3_sided, open:, enumerate_via_block:)
      end
    end
  end

  ##############################
  # ...and for the "dynamic" version

  def test_dynamic_quadrant_calls
    %i[largest_y_in_ne largest_y_in_nw smallest_x_in_ne largest_x_in_nw].each do |method|
      before_and_after_deletion_pair do |pst_pair|
        check_quadrant_calc_pair(pst_pair, :largest_y_in_ne)
      end
    end
  end

  def test_dynamic_3_sided_calls
    before_and_after_deletion_pair do |pst_pair|
      check_3_sided_calc_pair(pst_pair, :largest_y_in_3_sided)
    end
  end

  def test_dynamic_enumerate_3_sided_calls
    [true, false].each do |open|
      [true, false].each do |enumerate_via_block|
        before_and_after_deletion_pair do |pst_pair|
          check_3_sided_calc_pair(pst_pair, :enumerate_3_sided, open:, enumerate_via_block:)
        end
      end
    end
  end

  private def before_and_after_deletion_pair
    pst_pair = dynamic_max_pst_pair
    yield pst_pair

    pst_pair.delete_top!
    yield pst_pair
  end

  ########################################
  # Analagous tests for the MinPST

  def test_min_pst_quadrant_calls
    %i[smallest_y_in_se smallest_y_in_sw smallest_x_in_se largest_x_in_sw].each do |method|
      [true, false].each do |open|
        check_quadrant_calc_pair(min_pst_pair, method, open: open)
      end
    end
  end

  def test_min_pst_3_sided_calls
    [true, false].each do |open|
      check_3_sided_calc_pair(min_pst_pair, :smallest_y_in_3_sided, open:)
    end
  end

  def test_min_pst_enumerate_3_sided_calls
    [true, false].each do |open|
      [true, false].each do |enumerate_via_block|
        check_3_sided_calc_pair(min_pst_pair, :enumerate_3_sided, open:, enumerate_via_block:)
      end
    end
  end

  ########################################
  # Some regression tests on inputs found to be bad during testing

  def test_bad_inputs_for_max_smallest_x_in_ne
    check_one = lambda do |data, *method_params, actual_highest|
      check_one_case(MaxPrioritySearchTree, :smallest_x_in_ne, data, *method_params, actual_highest)
    end

    check_one.call(
      [[6, 19], [9, 18], [15, 17], [2, 16], [11, 13], [16, 12], [19, 10], [4, 6], [8, 15], [10, 7],
       [12, 11], [13, 9], [14, 4], [17, 2], [18, 3], [1, 5], [3, 1], [5, 8], [7, 14]],
      4, 15,
      Point.new(6, 19)
    )
  end

  def test_bad_inputs_for_max_largest_y_in_3_sided
    check_one = lambda do |data, *method_params, actual_highest|
      check_one_case(MaxPrioritySearchTree, :largest_y_in_3_sided, data, *method_params, actual_highest)
    end

    # Early versions of code couldn't even handle these!
    check_one.call([[1, 1]], 0, 1, 0, Point.new(1, 1))

    check_one.call(
      [[4, 5], [1, 4], [5, 2], [2, 1], [3, 3]],
      2, 3, 2,
      Point.new(3, 3)
    )

    check_one.call(
      [[8, 8], [1, 7], [6, 5], [2, 6], [4, 3], [5, 1], [7, 2], [3, 4]],
      3, 5, 0,
      Point.new(3, 4)
    )

    check_one.call(
      [[7, 8], [1, 5], [5, 7], [2, 3], [4, 1], [6, 6], [8, 4], [3, 2]],
      3, 4, 1,
      Point.new(3, 2)
    )
  end

  def test_bad_inputs_for_max_enumerate_3_sided
    check_one = lambda do |data, *method_params, actual_vals, open: false|
      actual_set = Set.new(actual_vals.map { |x, y| Point.new(x, y) })
      check_one_case(MaxPrioritySearchTree, :enumerate_3_sided, data, *method_params, actual_set, open:)
    end

    # LogicErrors
    check_one.call([[1, 3], [2, 1], [3, 2]], 2, 3, 0, [[2, 1], [3, 2]])
    check_one.call([[2, 5], [4, 3], [5, 4], [1, 2], [3, 1]], 4, 5, 4, [[5, 4]])

    # These had timeouts in early code
    check_one.call([[1, 1]], 0, 1, 0, [[1, 1]])
    check_one.call([[2, 2], [1, 1]], 0, 1, 1, [[1, 1]])
    check_one.call([[2, 6], [3, 5], [5, 3], [1, 4], [4, 2], [6, 1]], 3, 5, 5, [[3, 5]])
    check_one.call([[5, 10], [7, 8], [10, 9], [2, 7], [6, 4], [8, 6], [9, 5], [1, 1], [3, 2], [4, 3]], 5, 6, 0, [[6, 4], [5, 10]])

    # These ones didn't time out, but returned bad values
    check_one.call([[2, 3], [1, 1], [3, 2]], 0, 1, 0, [[1, 1]])
    check_one.call([[7, 7], [1, 5], [4, 6], [2, 2], [3, 1], [5, 4], [6, 3]], 5, 6, 3, [[5, 4], [6, 3]])
    check_one.call(
      [[8, 12], [6, 11], [10, 10], [2, 7], [7, 8], [11, 9], [12, 1], [1, 5], [3, 6], [4, 2], [5, 3], [9, 4]],
      3, 10, 0,
      [[8, 12], [10, 10], [6, 11], [9, 4], [5, 3], [3, 6], [4, 2], [7, 8]]
    )
    check_one.call(
      [[4, 14], [5, 13], [13, 12], [2, 11], [8, 9], [10, 10], [14, 8], [1, 4], [3, 3], [6, 7], [7, 1], [9, 5], [11, 6], [12, 2]],
      6, 13, 0,
      [[6, 7], [11, 6], [10, 10], [8, 9], [12, 2], [9, 5], [7, 1], [13, 12]]
    )

    # Open region
    check_one.call([[4, 2], [3, 2], [1, 3], [2, 3]], 1, 2, 3, [], open: true)
  end

  def test_bad_inputs_for_largest_x_in_nw
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MaxPrioritySearchTree, :largest_x_in_nw, data, *method_params, actual_leftmost)
    end

    check_one.call([[3, 6], [2, 5], [6, 3], [1, 1], [4, 4], [5, 2]], 5, 2, Point.new(5, 2))
  end

  def test_bad_inputs_for_largest_y_in_nw
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MaxPrioritySearchTree, :largest_y_in_nw, data, *method_params, actual_leftmost)
    end

    # Now we are allowing duplicated y values
    check_one.call([[3, 3], [2, 2], [1, 2]], 2, 1, Point.new(1, 2))
  end

  def test_bad_inputs_for_largest_y_in_ne
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MaxPrioritySearchTree, :largest_y_in_ne, data, *method_params, actual_leftmost)
    end
    check_one.call([[1, 3], [2, 2], [3, 1]], 2, 1, Point.new(2, 2))
  end

  def test_bad_inputs_for_dynamic_largest_x_in_nw
    check_one_dynamic_case(
      MaxPrioritySearchTree, :largest_x_in_nw,
      [[7, 5], [9, 3], [5, 8], [2, 2], [8, 5], [6, 7], [1, 7], [10, 10], [4, 4], [3, 1]],
      9, 1,
      [[10, 10], [5, 8], [1, 7], [6, 7], [7, 5], [8, 5], [4, 4], [9, 3], [2, 2], [3, 1]],
      [-INFINITY, INFINITY]
    )
  end

  def test_bad_inputs_for_dynamic_enumerate_3_sided
    check_one = lambda do |points, *method_params, deleted_point, expected_points|
      points = points.map { Point.new(*_1) }
      deleted_point = Point.new(*deleted_point)
      expected_result = Set.new(expected_points.map { Point.new(*_1) })

      dynamic_pst = MaxPrioritySearchTree.new(points, dynamic: true)
      assert_equal deleted_point, dynamic_pst.delete_top! # check we are deleting what we expect

      assert_equal expected_result, dynamic_pst.enumerate_3_sided(*method_params)
    end

    check_one.call([[2, 2], [1, 2], [3, 2]], 3, 3, 2, [1, 2], [[3, 2]])
    check_one.call([[1, 3], [3, 2], [2, 2]], 1, 2, 2, [1, 3], [[2, 2]])
    check_one.call([[1, 3], [2, 3], [3, 3]], 1, 1, 3, [1, 3], [])
  end

  private def check_one_case(klass, method, data, *method_params, expected_val, open: false)
    calculated_val = Timeout::timeout(timeout_time_s) do
      pst = klass.new(data.map { |x, y| Point.new(x, y) })
      calculated_val = pst.send(method, *method_params, open:)
    end
    assert_equal expected_val, calculated_val
  end

  private def check_one_dynamic_case(klass, method, points, *method_params, deleted_points, expected_val)
    points.map! { Point.new(*_1) }
    deleted_points = Set.new(deleted_points.map { Point.new(*_1) })
    expected_result = Point.new(*expected_val)

    dynamic_pst = klass.new(points, dynamic: true)
    actually_deleted_points = Set.new
    deleted_points.size.times do
      actually_deleted_points << dynamic_pst.delete_top!
    end
    assert_equal deleted_points, actually_deleted_points # check we are deleting what we expect
    assert_equal expected_result, dynamic_pst.send(method, *method_params)
  end

  ########################################
  # Some quasi-tests that search for inputs that lead to assertion failures.
  #
  # The do the following a bunch of times or until a problem is found:
  # - create some random points
  # - call a particular method on a given PST and check that there isn't a timeout, and exception, or an unexpected return value
  #
  # If a problem is found, the problematic inputs are written to stdout so the problem can be investigated.
  #
  # They are all no-ops unless the environment variable find_bad is set

  BAD_INPUT_SEARCH_ATTEMPT_LIMIT = 1_000

  def test_max_find_bad_input_for_smallest_x_in_ne
    search_for_bad_inputs(MaxPrioritySearchTree, :smallest_x_in_ne) do |points|
      params_for_find_bad_case_pair(points, :smallest_x_in_ne)
    end
  end

  def test_max_find_bad_input_for_largest_y_in_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_3_sided) do |points|
      params_for_find_bad_case_pair(points, :largest_y_in_3_sided)
    end
  end

  def test_max_find_bad_input_for_enumerate_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :enumerate_3_sided) do |points|
      params_for_find_bad_case_pair(points, :enumerate_3_sided)
    end
  end

  def test_max_find_bad_input_for_enumerate_open_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :enumerate_3_sided, open: true) do |points|
      params_for_find_bad_case_pair(points, :enumerate_3_sided, open: true)
    end
  end

  def test_max_find_bad_input_for_largest_x_in_nw
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_x_in_nw) do |points|
      params_for_find_bad_case_pair(points, :largest_x_in_nw)
    end
  end

  def test_max_find_bad_input_for_largest_y_in_ne
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_ne) do |points|
      params_for_find_bad_case_pair(points, :largest_y_in_ne)
    end
  end

  def test_max_find_bad_input_for_largest_y_in_nw
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_nw) do |points|
      params_for_find_bad_case_pair(points, :largest_y_in_nw)
    end
  end

  def test_max_find_bad_input_for_construction
    search_for_bad_inputs(MaxPrioritySearchTree, nil)
  end

  def test_dynamic_max_find_bad_input_for_largest_y_in_ne
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case_pair(points, :largest_y_in_ne) }
    )
  end

  def test_dynamic_max_find_bad_input_for_largest_y_in_nw
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case_pair(points, :largest_y_in_nw) }
    )
  end

  def test_dynamic_max_find_bad_input_for_smallest_x_in_ne
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case_pair(points, :smallest_x_in_ne) }
    )
  end

  def test_dynamic_max_find_bad_input_for_largest_x_in_nw
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case_pair(points, :smallest_x_in_ne) }
    )
  end

  def test_dynamic_max_find_bad_input_for_largest_y_in_three_sided
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case_pair(points, :largest_y_in_3_sided) }
    )
  end

  def test_dynamic_max_find_bad_input_for_enumerate_in_three_sided
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case_pair(points, :enumerate_3_sided) }
    )
  end

  private def params_for_find_bad_case_pair(pairs, method, open: false)
    x_min, x_max = pairs.map(&:x).minmax
    y_min, y_max = pairs.map(&:y).minmax
    x0 = rand(x_min..x_max)
    y0 = rand(y_min..y_max)

    if method =~ /3_sided/
      x1 = rand(x0..x_max)
      expected = SimplePrioritySearchTree.new(pairs).send(method, x0, x1, y0, open:)
      [[x0, x1, y0], expected]
    else
      expected = SimplePrioritySearchTree.new(pairs).send(method, x0, y0, open:)
      [[x0, y0], expected]
    end
  end

  # ...The same idea, but for a dynamic PST in which we are deleting a point before calling a method
  private def params_for_dynamic_find_bad_case_pair(points, method)
    x_min, x_max = points.map(&:x).minmax
    y_min, y_max = points.map(&:y).minmax
    x0 = rand(x_min..x_max)
    y0 = rand(y_min..y_max)

    max_pst = MaxPrioritySearchTree.new(points.clone, dynamic: true)
    simple_pst = SimplePrioritySearchTree.new(points.clone)
    pst_pair = PSTPair.new(max_pst, simple_pst)

    # Delete some points
    loop do
      pst_pair.delete_top!
      break if pst_pair.empty? || rand > 0.9
    end

    deleted_list = "[#{simple_pst.deletions.join(', ')}]"

    if method =~ /3_sided/
      x1 = rand(x0..x_max)
      extra_message = "(x0, x1, y0) = (#{x0}, #{x1}, #{y0}); deleted #{deleted_list}"
      args = [x0, x1, y0]
    else
      extra_message = "(x0, y0) = (#{x0}, #{y0}); deleted #{deleted_list}"
      args = [x0, y0]
    end
    expected_value = simple_pst.send(method, *args)
    actual_value = max_pst.send(method, *args)

    #byebug unless expected_value == actual_value
    [expected_value, actual_value, extra_message]
  end

  ########################################
  # Harness for profiling
  #
  # These aren't actually tests and make no assertions. THey do nothing unless the >profile< environment variable is set.

  def test_profiling
    return unless ENV['profile']

    # method = :enumerate_3_sided
    method = :largest_x_in_nw
    pst_pair = make_max_pst_pair
    profile(method) do
      check_quadrant_calc_pair(pst_pair, :max, :y, :nw)
    end
  end

  # # Not an actual test. We don't make any assertions. Do nothing at all unless the profile environment variable is set
  private def profile(tag)
    return unless ENV['profile']

    # Boilerplate lifted from my ad hoc code from one of the work projects
    profile = RubyProf::Profile.new(merge_fibers: true)

    profile.exclude_common_methods!
    profile.exclude_methods!([/Array#/, /Rational#/, /Integer#/, /Enumerator#/, /Range#/, /Fixnum#/, /Enumerable#/])

    profile.start
    _result = yield
    profile.stop

    FileUtils.mkdir_p("profile")
    flat_printer = RubyProf::FlatPrinter.new(profile)
    graph_printer = RubyProf::GraphPrinter.new(profile)
    call_tree_printer = RubyProf::CallTreePrinter.new(profile)
    stack_printer = RubyProf::CallStackPrinter.new(profile)

    File.open("profile/flat_#{tag}.out",  "w") {|f| flat_printer.print(f)}
    File.open("profile/graph_#{tag}.out", "w") {|f| graph_printer.print(f)}

    # Just to annoy me, the CallTreePrinter class now does paths differently and in a way
    # that is poorly documented.
    call_tree_printer.print(path: "profile", profile: tag.to_s)
    File.open("profile/stack_#{tag}.html", 'w') {|f| stack_printer.print(f)}
  end

  # Search for a set of bad input that causes klass#method to return the wrong value.
  #
  # If we find such data then output the details to stdout and fail an assertion. Otherwise return true.
  #
  # There are several options for the method argument
  # - If method.nil? we just construct a PST of the given klass with verification turned on.
  # - If method is a symbol we construct a PST (without verification) we do several things
  #   - yield the generated data points to an expected block to get the method parameters to use and the expected value
  #   - call the given method, and check the answer
  # - Otherwise it must be a callable object expecting to receive the data points
  #   - The lambda does whatever it wants and returns two or three things
  #     - the expected value of the operation
  #     - the actual value of the operation
  #     - (optional) an additional message to display if the answers don't agree
  #
  # Use case for a lambda: a dynamic PST that we construct, remove one or more elements from, and then call a method
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
  private def search_for_bad_inputs(klass, method, open: false)
    return unless find_bad_inputs?

    BAD_INPUT_SEARCH_ATTEMPT_LIMIT.times do
      pairs = raw_data(@size).shuffle

      timeout = false

      # Scope!
      error_message = calculated_value = extra_message = expected_value = nil
      begin
        Timeout::timeout(timeout_time_s) do
          case method
          when Symbol
            method_params, expected_value = yield(pairs)
            pst = klass.new(pairs.clone)
            calculated_value = pst.send(method, *method_params, open:)
            extra_message = "params = [#{method_params.join(', ')}]"
          when nil
            _pst = klass.new(pairs.clone, verify: true)
          else
            expected_value, calculated_value, extra_message = method.call(pairs)
          end
        end
      rescue Timeout::Error
        puts "*\n*\n"
        puts "* >>>>>>>TIMEOUT<<<<<<<<"
        puts "*\n*\n"
        timeout = true
      rescue InternalLogicError => e
        puts "*\n*\n"
        puts "* >>>>>>>ERROR<<<<<<<<"
        puts e.message
        puts "*\n*\n"
        error_message = e.message
      end

      next unless error_message || timeout || method && (expected_value != calculated_value)

      pair_data = pairs.map { |p| "[#{p.x},#{p.y}]" }.join(', ')
      puts "data = [#{pair_data}]"
      if method
        if extra_message
          puts "extra: #{extra_message}"
        end

        # tag = "#{method}(#{args.join(', ')}) #{'/open' if open} #{'/enumerate_via_block' if enumerate_via_block}"

        assert_equal expected_value, calculated_value
      else
        assert false
      end
    end
  end

  private def find_bad_inputs?
    ENV['find_bad']
  end

  private def timeout_time_s
    ENV['debug'] ? 1e10 : 0.5 # Timeout doesn't allow Infinity
  end

  ########################################
  # Helpers

  private def max_pst_pair
    @max_pst_pair ||= make_max_pst_pair
  end

  private def make_max_pst_pair(pairs = nil)
    pairs ||= @common_raw_data.shuffle
    max_pst = MaxPrioritySearchTree.new(pairs.clone)
    simple_pst = SimplePrioritySearchTree.new(pairs.clone)
    PSTPair.new(max_pst, simple_pst)
  end

  private def dynamic_max_pst_pair
    if !@dynamic_max_pst_pair || @dynamic_max_pst_pair.empty?
      pairs = @common_raw_data.shuffle
      dynamic_max_pst = MaxPrioritySearchTree.new(pairs.clone, dynamic: true)
      simple_pst = SimplePrioritySearchTree.new(pairs.clone)
      @dynamic_max_pst_pair = PSTPair.new(dynamic_max_pst, simple_pst)
    end
    @dynamic_max_pst_pair
  end

  private def min_pst_pair
    @min_pst_pair ||= begin
                        pairs = @common_raw_data.shuffle
                        min_pst = MinPrioritySearchTree.new(pairs.clone)
                        simple_pst = SimplePrioritySearchTree.new(pairs.clone)
                        PSTPair.new(min_pst, simple_pst)
                      end
  end

  # Check that a MaxPST calculation in a quadrant gives the correct result
  #
  # - pst_pair: a PST/SimplePst pair used to perform the calculation
  # - method: the method to call on the PSTs
  # - open: is the region open or closed?
  private def check_quadrant_calc_pair(pst_pair, method, open: false)
    simple_pst = pst_pair.simple_pst
    100.times do
      x0 = rand(simple_pst.min_x..simple_pst.max_x)
      y0 = rand(simple_pst.min_y..simple_pst.max_y)
      check_calculation_pair(pst_pair, method, x0, y0, open:)
    end
  end

  # Check that a MaxPST calculation in a three sided region gives the correct result
  #
  # - pst_pair: a PST/SimplePst pair used to perform the calculation
  # - method: the method to call on the PSTs
  # - enumerate_via_block: should the calculation yield to a block?
  # - open: is the region open or closed?
  private def check_3_sided_calc_pair(pst_pair, method, enumerate_via_block: false, open: false)
    simple_pst = pst_pair.simple_pst

    100.times do
      x0 = rand(simple_pst.min_x..simple_pst.max_x)
      x1 = rand(x0..simple_pst.max_x)
      y0 = rand(simple_pst.min_y..simple_pst.max_y)
      check_calculation_pair(pst_pair, method, x0, x1, y0, enumerate_via_block:, open:)
    end
  end

  private def check_calculation_pair(pst_pair, method, *args, enumerate_via_block: false, open: false)
    is_min = pst_pair.pst.is_a?(MinPrioritySearchTree)

    tag = "#{method}(#{args.join(', ')}) #{'/open' if open} #{'/enumerate_via_block' if enumerate_via_block}"

    # This is a wart
    expected_value = if is_min && method == :enumerate_3_sided
                       pst_pair.simple_pst.send(method, *args, open:, for_min_pst: true)
                     else
                       pst_pair.simple_pst.send(method, *args, open:)
                     end

    calculated_value = if enumerate_via_block
                         result = Set.new
                         pst_pair.pst.send(method, *args, open:) { |point| result << point }
                         result
                       else
                         pst_pair.pst.send(method, *args, open:)
                       end
    assert_equal expected_value, calculated_value, tag
  end

  # By default we take x values 1, 2, ..., size and choose random integer y values in 1..size.
  #
  # If the environment variable 'floats' is set, instead choose random values in 0..1 for both coordinates.
  private def raw_data(size)
    if ENV['floats']
      (1..size).map { Point.new(rand, rand) }
    else
      list = (1..size).to_a
      y_vals = (1..size).map { rand(1..size) }
      list.zip(y_vals).map { Point.new(*_1) }
    end
  end

  # Do most of the work of a MaxPST and a MinPST in a very slow way, the simplest way possible. It is used to test expected result.
  #
  # We don't support #delete_top!, as we can't easily keep track of what would be at the top of a real PST heap. So we only provide
  # a #delete! method that deletes a specific point.
  #
  # As a convenience we provide min_x, max_x, min_y, and max_y
  class SimplePrioritySearchTree
    attr_reader :points, :min_x, :max_x, :min_y, :max_y, :deletions

    def initialize(points)
      @points = points
      @size = @points.size

      @points_by_x = points.sort_by(&:x)
      @min_x, @max_x = @points_by_x.map(&:x).minmax
      @min_y, @max_y = points.map(&:y).minmax

      @deletions = []
    end

    # Say that point has been deleted.
    def delete!(point)
      raise "Already deleted" if @deletions.include?(point)
      raise "Not a point in this PST" unless @points.include?(point)

      @deletions << point
    end

    def empty?
      @points.size - @deletions.size == 0
    end

    def largest_y_in_ne(x0, y0, open: false)
      ne_quadrant(x0, y0, open:).max_by(&:y) || Point.new(INFINITY, -INFINITY)
    end

    def smallest_y_in_se(x0, y0, open: false)
      se_quadrant(x0, y0, open:).min_by(&:y) || Point.new(INFINITY, INFINITY)
    end

    def largest_y_in_nw(x0, y0, open: false)
      nw_quadrant(x0, y0, open:).max_by(&:y) || Point.new(-INFINITY, -INFINITY)
    end

    def smallest_y_in_sw(x0, y0, open: false)
      sw_quadrant(x0, y0, open:).min_by(&:y) || Point.new(-INFINITY, INFINITY)
    end

    def smallest_x_in_ne(x0, y0, open: false)
      ne_quadrant(x0, y0, open:).min_by(&:x) || Point.new(INFINITY, INFINITY)
    end

    def largest_x_in_nw(x0, y0, open: false)
      nw_quadrant(x0, y0, open:).max_by(&:x) || Point.new(-INFINITY, INFINITY)
    end

    def smallest_x_in_se(x0, y0, open: false)
      se_quadrant(x0, y0, open:).min_by(&:x) || Point.new(INFINITY, -INFINITY)
    end

    def largest_x_in_sw(x0, y0, open: false)
      sw_quadrant(x0, y0, open:).max_by(&:x) || Point.new(-INFINITY, -INFINITY)
    end

    def largest_y_in_3_sided(x0, x1, y0, open: false)
      enumerate_3_sided(x0, x1, y0, open:).max_by(&:y) || Point.new(INFINITY, -INFINITY)
    end

    def smallest_y_in_3_sided(x0, x1, y0, open: false)
      enumerate_3_sided(x0, x1, y0, open:, for_min_pst: true).min_by(&:y) || Point.new(INFINITY, INFINITY)
    end

    # for_min_pst: is a wart. SInce we aren't either a MinPST or a MaxPST, we need to know which one we are emulating.
    def enumerate_3_sided(x0, x1, y0, open: false, for_min_pst: false)
      quadrant_vals = if for_min_pst
                        se_quadrant(x0, y0, open:)
                      else
                        ne_quadrant(x0, y0, open:)
                      end

      points = if open
                 quadrant_vals.reject { |pt| pt.x >= x1 }
               else
                 quadrant_vals.reject { |pt| pt.x > x1 }
               end

      if block_given?
        points.each { |pt| yield pt }
      else
        Set.new points
      end
    end

    private

    def ne_quadrant(x0, y0, open: false)
      if open
        rightward_points(x0).select { |pair| pair.x != x0 && pair.y > y0 }
      else
        rightward_points(x0).select { |pair| pair.y >= y0 }
      end
    end

    def nw_quadrant(x0, y0, open: false)
      if open
        leftward_points(x0).select { |pair| pair.x != x0 && pair.y > y0 }
      else
        leftward_points(x0).select { |pair| pair.y >= y0 }
      end
    end

    def se_quadrant(x0, y0, open: false)
      if open
        rightward_points(x0).select { |pair| pair.x != x0 && pair.y < y0 }
      else
        rightward_points(x0).select { |pair| pair.y <= y0 }
      end
    end

    def sw_quadrant(x0, y0, open: false)
      if open
        leftward_points(x0).select { |pair| pair.x != x0 && pair.y < y0 }
      else
        leftward_points(x0).select { |pair| pair.y <= y0 }
      end
    end

    def three_sided_up(x0, x1, y0, open: false)
      if open
        ne_quadrant(x0, y0, open:).reject { |pt| pt.x >= x1 }
      else
        ne_quadrant(x0, y0, open:).reject { |pt| pt.x > x1 }
      end
    end

    def three_sided_down(x0, x1, y0, open: false)
      if open
        se_quadrant(x0, y0, open:).reject { |pt| pt.x >= x1 }
      else
        se_quadrant(x0, y0, open:).reject { |pt| pt.x > x1 }
      end
    end

    # Points (x,y) in @data with x >= x0
    private def rightward_points(x0)
      return [] if points.empty?

      points = if x0 <= @min_x
                 @points_by_x
               elsif x0 > @max_x
                 []
               else
                 first_idx = @points_by_x.bsearch_index { |v| v.x >= x0 }
                 @points_by_x[first_idx..]
               end
      points - @deletions
    end

    # Points (x,y) in @data with x <= x0
    private def leftward_points(x0)
      return [] if points.empty?

      points = if x0 >= @max_x
                 @points_by_x
               elsif x0 < @min_x
                 []
               else
                 first_idx = @points_by_x.bsearch_index { |v| v.x >= x0 }
                 if @points_by_x[first_idx].x == x0
                   @points_by_x[..first_idx]
                 else
                   @points_by_x[...first_idx]
                 end
               end
      points - @deletions
    end
  end
end
