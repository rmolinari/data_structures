# if ENV['coverage']
#   require 'simplecov'
#   SimpleCov.start
# end

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
    raw_data = raw_data(@size)
    @point_finder = PointFinder.new(raw_data)
    @open_point_finder = PointFinder.new(raw_data, open: true)
    @dynamic_point_finder = PointFinder.new(raw_data)
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

  def test_max_pst_largest_y_in_ne
    check_quadrant_calc(max_pst, :max, :y, :ne)
  end

  def text_max_pst_largest_y_in_open_ne
    check_quadrant_calc(max_pst, :max, :y, :ne, open: true)
  end

  def test_max_pst_largest_y_in_open_ne
    data = [[0, 2], [1, 1], [2, 0]].map { |x, y| Point.new(x, y) }
    pst = MaxPrioritySearchTree.new(data)

    assert_equal Point.new(1, 1), pst.largest_y_in_ne(0, 0, open: true)
  end

  def test_max_pst_largest_y_in_nw
    check_quadrant_calc(max_pst, :max, :y, :nw)
  end

  def test_max_pst_largest_y_in_open_nw
    check_quadrant_calc(max_pst, :max, :y, :nw, open: true)
  end

  def test_max_pst_smallest_x_in_ne
    check_quadrant_calc(max_pst, :min, :x, :ne)
  end

  def test_max_pst_smallest_x_in_open_ne
    check_quadrant_calc(max_pst, :min, :x, :ne, open: true)
  end

  def test_max_pst_largest_x_in_nw
    check_quadrant_calc(max_pst, :max, :x, :nw)
  end

  def test_max_pst_largest_x_in_open_nw
    check_quadrant_calc(max_pst, :max, :x, :nw, open: true)
  end

  def test_max_pst_largest_y_in_3_sided
    check_3_sided_calc(max_pst, :max, :y)
  end

  def test_max_pst_largest_y_in_open_3_sided
    check_3_sided_calc(max_pst, :max, :y, open: true)
  end

  def test_max_pst_enumerate_3_sided
    check_3_sided_calc(max_pst, :all, nil)
    check_3_sided_calc(max_pst, :all, nil, enumerate_via_block: true)
  end

  ##############################
  # ...and for the "dynamic" version

  def test_dynamic_max_pst_largest_y_in_ne
    before_and_after_deletion do |pst|
      check_quadrant_calc(pst, :max, :y, :ne)
    end
  end

  def test_dynamic_max_pst_largest_y_in_nw
    before_and_after_deletion do |pst|
      check_quadrant_calc(pst, :max, :y, :nw)
    end
  end

  def test_pst_smallest_x_in_ne
    before_and_after_deletion do |pst|
      check_quadrant_calc(pst, :min, :x, :ne)
    end
  end

  def test_pst_largest_x_in_nw
    before_and_after_deletion do |pst|
      check_quadrant_calc(pst, :max, :x, :nw)
    end
  end

  def test_pst_largest_y_in_3_sided
    before_and_after_deletion do |pst|
      check_3_sided_calc(pst, :max, :y)
    end
  end

  def test_dynamic_max_pst_enumerate_3_sided
    before_and_after_deletion do |pst|
      check_3_sided_calc(dynamic_max_pst, :all, nil)
      check_3_sided_calc(dynamic_max_pst, :all, nil, enumerate_via_block: true)
    end
  end

  private def before_and_after_deletion
    dynamic_context do
      pst = dynamic_max_pst
      yield pst

      deleted_pt = pst.delete_top!
      @dynamic_point_finder.delete!(deleted_pt)
      yield pst
    end
  end

  ########################################
  # Analagous tests for the MinPST

  def test_min_pst_smallest_y_in_se
    check_quadrant_calc(min_pst, :min, :y, :se)
  end

  def test_min_pst_smallest_y_in_sw
    check_quadrant_calc(min_pst, :min, :y, :sw)
  end

  def test_min_pst_smallest_x_in_se
    check_quadrant_calc(min_pst, :min, :x, :se)
  end

  def test_min_pst_largest_x_in_sw
    check_quadrant_calc(min_pst, :max, :x, :sw)
  end

  def test_min_pst_smallest_y_in_3_sided
    check_3_sided_calc(min_pst, :min, :y)
  end

  def test_min_pst_enumerate_3_sided
    check_3_sided_calc(min_pst, :all, nil)
    check_3_sided_calc(min_pst, :all, nil, enumerate_via_block: true)
  end

  ########################################
  # Some regression tests on inputs found to be bad during testing

  def test_bad_inputs_for_max_smallest_x_in_ne
    check_one = lambda do |data, *method_params, actual_highest|
      check_one_case(MaxPrioritySearchTree, :smallest_x_in_ne, data, *method_params, actual_highest)
    end

    check_one.call(
      [[6,19], [9,18], [15,17], [2,16], [11,13], [16,12], [19,10], [4,6], [8,15], [10,7], [12,11], [13,9], [14,4], [17,2], [18,3], [1,5], [3,1], [5,8], [7,14]],
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
      [[4,5], [1,4], [5,2], [2,1], [3,3]],
      2, 3, 2,
      Point.new(3, 3)
    )

    check_one.call(
      [[8,8], [1,7], [6,5], [2,6], [4,3], [5,1], [7,2], [3,4]],
      3, 5, 0,
      Point.new(3, 4)
    )

    check_one.call(
      [[7,8], [1,5], [5,7], [2,3], [4,1], [6,6], [8,4], [3,2]],
      3, 4, 1,
      Point.new(3, 2)
    )
  end

  def test_bad_inputs_for_max_enumerate_3_sided
    check_one = lambda do |data, *method_params, actual_vals|
      actual_set = Set.new(actual_vals.map { |x, y| Point.new(x, y) })
      check_one_case(MaxPrioritySearchTree, :enumerate_3_sided, data, *method_params, actual_set)
    end

    # LogicErrors
    check_one.call([[1,3], [2,1], [3,2]],               2, 3, 0, [[2, 1], [3, 2]])
    check_one.call([[2,5], [4,3], [5,4], [1,2], [3,1]], 4, 5, 4, [[5, 4]])

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

  def test_bad_inputs_for_largest_x_in_nw
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MaxPrioritySearchTree, :largest_x_in_nw, data, *method_params, actual_leftmost)
    end

    check_one.call([[3,6], [2,5], [6,3], [1,1], [4,4], [5,2]], 5, 2, Point.new(5, 2))
  end

  def test_bad_inputs_for_largest_y_in_nw
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MaxPrioritySearchTree, :largest_y_in_nw, data, *method_params, actual_leftmost)
    end

    # Now we are allowing duplicated y values
    check_one.call([[3,3], [2, 2], [1,2]], 2, 1, Point.new(1, 2))
  end

  def test_bad_inputs_for_largest_y_in_ne
    check_one = lambda do |data, *method_params, actual_leftmost|
      check_one_case(MaxPrioritySearchTree, :largest_y_in_ne, data, *method_params, actual_leftmost)
    end
    check_one.call([[1,3], [2,2], [3,1]], 2, 1, Point.new(2, 2))
  end

  def test_bad_inputs_for_dynamic_largest_x_in_nw
    check_one_dynamic_case(
      MaxPrioritySearchTree, :largest_x_in_nw,
      [[7,5], [9,3], [5,8], [2,2], [8,5], [6,7], [1,7], [10,10], [4,4], [3,1]],
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

    check_one.call([[2,2], [1,2], [3,2]], 3, 3, 2, [1, 2], [[3, 2]])
    check_one.call([[1,3], [3,2], [2,2]], 1, 2, 2, [1, 3], [[2, 2]])
    check_one.call([[1,3], [2,3], [3,3]], 1, 1, 3, [1, 3], [])
  end

  private def check_one_case(klass, method, data, *method_params, expected_val)
    calculated_val = Timeout::timeout(timeout_time_s) do
      pst = klass.new(data.map { |x, y| Point.new(x, y) })
      calculated_val = pst.send(method, *method_params)
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
      params_for_find_bad_case(points, :ne, :min_x)
    end
  end

  def test_max_find_bad_input_for_largest_y_in_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_3_sided) do |points|
      params_for_find_bad_case(points, :three_sided, :max_y)
    end
  end

  def test_max_find_bad_input_for_enumerate_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :enumerate_3_sided) do |points|
      params_for_find_bad_case(points, :three_sided, :all)
    end
  end

  def test_max_find_bad_input_for_largest_x_in_nw
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_x_in_nw) do |points|
      params_for_find_bad_case(points, :nw, :max_x)
    end
  end

  def test_max_find_bad_input_for_largest_y_in_ne
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_ne) do |points|
      params_for_find_bad_case(points, :ne, :max_y)
    end
  end

  def test_max_find_bad_input_for_largest_y_in_nw
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_nw) do |points|
      params_for_find_bad_case(points, :nw, :max_y)
    end
  end

  def test_max_find_bad_input_for_construction
    search_for_bad_inputs(MaxPrioritySearchTree, nil)
  end

  def test_dynamic_max_find_bad_input_for_largest_y_in_ne
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case(points, :ne, :max_y, :largest_y_in_ne) }
    )
  end

  def test_dynamic_max_find_bad_input_for_largest_y_in_nw
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case(points, :nw, :max_y, :largest_y_in_nw) }
    )
  end

  def test_dynamic_max_find_bad_input_for_smallest_x_in_ne
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case(points, :ne, :min_x, :smallest_x_in_ne) }
    )
  end

  def test_dynamic_max_find_bad_input_for_largest_x_in_nw
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case(points, :nw, :max_x, :largest_x_in_nw) }
    )
  end

  def test_dynamic_max_find_bad_input_for_largest_y_in_three_sided
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case(points, :three_sided, :max_y, :largest_y_in_3_sided) }
    )
  end

  def test_dynamic_max_find_bad_input_for_enumerate_in_three_sided
    search_for_bad_inputs(
      nil, # bad design in the method we call
      ->(points) { params_for_dynamic_find_bad_case(points, :three_sided, :all, :enumerate_3_sided) }
    )
  end

  # Work out values to return to search_for_bad_inputs
  private def params_for_find_bad_case(pairs, region, criterion)
    x_min, x_max = pairs.map(&:x).minmax
    y_min, y_max = pairs.map(&:y).minmax
    x0 = rand(x_min..x_max)
    y0 = rand(y_min..y_max)

    # Making all these calls to best_in is slow, but the computer doesn't mind
    if region == :three_sided
      x1 = rand(x0..x_max)
      expected = best_in(region, x0, x1, y0, by: criterion, among: pairs)
      [[x0, x1, y0], expected]
    else
      expected = best_in(region, x0, y0, by: criterion, among: pairs)
      [[x0, y0], expected]
    end
  end

  # ...The same idea, but for a dynamic PST in which we are deleting a point before calling a method
  private def params_for_dynamic_find_bad_case(points, region, criterion, method)
    x_min, x_max = points.map(&:x).minmax
    y_min, y_max = points.map(&:y).minmax
    x0 = rand(x_min..x_max)
    y0 = rand(y_min..y_max)

    deleted_pts = []
    pst = MaxPrioritySearchTree.new(points.clone, dynamic: true)

    # Delete some points
    loop do
      deleted_pts << pst.delete_top!
      break if pst.empty? || rand > 0.9
    end

    deleted_list = "[#{deleted_pts.join(', ')}]"

    if region == :three_sided
      x1 = rand(x0..x_max)
      extra_message = "(x0, x1, y0) = (#{x0}, #{x1}, #{y0}); deleted #{deleted_list}"

      expected_value = best_in(region, x0, x1, y0, by: criterion, among: points - deleted_pts)
      actual_value = pst.send(method, x0, x1, y0)

      [expected_value, actual_value, extra_message]
    else
      extra_message = "(x0, y0) = (#{x0}, #{y0}); deleted #{deleted_list}"

      expected_value = best_in(region, x0, y0, by: criterion, among: points - deleted_pts)
      actual_value = pst.send(method, x0, y0)

      [expected_value, actual_value, extra_message]
    end
  end

  ########################################
  # Harness for profiling
  #
  # These aren't actually tests and make no assertions. THey do nothing unless the >profile< environment variable is set.

  def test_profiling
    return unless ENV['profile']

    # method = :enumerate_3_sided
    method = :largest_x_in_nw
    pst = MaxPrioritySearchTree.new(@point_finder.points.shuffle)
    profile(method) do
      check_quadrant_calc(pst, :max, :y, :nw)
      # 100.times do
      #   x0 = rand(@size)
      #   # x1 = rand(x0..@size)
      #   y0 = rand(@size)
      #   # pst.send(method, x0, x1, y0)
      #   pst.send(method, x0, y0)
      # end
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
    call_tree_printer.print(path: "profile", profile: "#{tag}")
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
  private def search_for_bad_inputs(klass, method)
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
            calculated_value = pst.send(method, *method_params)
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
      if method
        puts "data = [#{pair_data}]"
        if extra_message
          puts "extra: #{extra_message}"
        end

        assert_equal expected_value, calculated_value
      else
        puts "data = [#{pair_data}]"

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

  private def max_pst
    @max_pst ||= MaxPrioritySearchTree.new(@point_finder.points.shuffle)
  end

  private def dynamic_max_pst
    @dynamic_max_pst ||= MaxPrioritySearchTree.new(@point_finder.points.shuffle, dynamic: true)

    if @dynamic_max_pst.empty?
      # make a new one
      @dynamic_max_pst = MaxPrioritySearchTree.new(@point_finder.points.shuffle, dynamic: true)
      @dynamic_point_finder.reset!
    end

    @dynamic_max_pst
  end

  private def min_pst
    @min_pst ||= MinPrioritySearchTree.new(@point_finder.points.shuffle)
  end

  # Check that a MaxPST calculation in a quadrant gives the correct result
  #
  # - criterion: :min or :max
  # - dimension: :x or :y
  # - region: :ne or :nw
  # - open: is the region open or closed?
  private def check_quadrant_calc(pst, criterion, dimension, region, open: false)
    pst.must_be
    criterion.must_be_in [:min, :max]
    dimension.must_be_in [:x, :y]
    region.must_be_in [:ne, :nw, :se, :sw]

    100.times do
      x0 = rand(@point_finder.min_x..@point_finder.max_x)
      y0 = rand(@point_finder.min_x..@point_finder.max_x)
      check_calculation(pst, criterion, dimension, region, x0, y0, open:)
    end
  end

  # Check that a MaxPST calculation in a three sided region gives the correct result
  #
  # - criterion: :max or :all
  # - dimension: :y or nil
  private def check_3_sided_calc(pst, criterion, dimension, enumerate_via_block: false, open: false)
    criterion.must_be_in [:min, :max, :all]
    dimension.must_be :y if dimension

    100.times do
      x0 = rand(@point_finder.min_x..@point_finder.max_x)
      x1 = rand(x0..@point_finder.max_x)
      y0 = rand(@point_finder.min_x..@point_finder.max_x)
      check_calculation(pst, criterion, dimension, :three_sided, x0, x1, y0, enumerate_via_block:, open:)
    end
  end

  # Check that the PST correctly finds the desired point in a stated region
  #
  # property: :min, :max, or :all (for enumerate)
  # dimension: the dimension we are "optimizing", :x or :y, ignored when property is :all
  # region: :ne, :nw, :three_sided
  # args: the args that bound the region
  # enumerate_via_block: we are enumerating a set of points. Instead of receiving the set as a return value, get them via a block to
  #       which the called code is expected to yield
  #
  # TODO: have it work out the default_result itself.
  private def check_calculation(pst, property, dimension, region, *args, enumerate_via_block: false, open: false)
    is_min_pst = pst.is_a? MinPrioritySearchTree

    region.must_be_in [:ne, :nw, :se, :sw, :three_sided]
    dimension.must_be_in [:x, :y, nil]
    property.must_be_in [:min, :max, :all]

    raise 'x-dimension calculations not supported in 3-sided region' if region == :three_sided && dimension == :x
    raise 'dimension must be given unless we are enumerating' if property != :all && !dimension
    raise 'enumeration via a block only makes sense with a property of :all' if enumerate_via_block && property != :all

    if is_min_pst
      raise 'maximizing in the y-dimension is not supported by a MinPST' if property == :max && dimension == :y
    else
      raise 'minimizing in the y-dimension is not supported by a MaxPST' if property == :min && dimension == :y
    end

    if property == :all
      method = "enumerate_3_sided"
      criterion = :all
    else
      method_word1 = property == :min ? :smallest : :largest
      method_word2 = dimension
      method_word4 = region == :three_sided ? '3_sided' : region

      method = "#{method_word1}_#{method_word2}_in_#{method_word4}".to_sym
      criterion = "#{property}_#{dimension}".to_sym
    end

    expected = best_in(region, *args, by: criterion, is_min_pst:, open:)
    calculated = if enumerate_via_block
                   vals = Set.new
                   pst.send(method, *args, open:) { vals << _1 }
                   vals
                 else
                   pst.send(method, *args, open:)
                 end
    assert_equal expected, calculated, "Args: #{args.join(', ')}, open: #{open}"
  end

  # The "best" value in a given region by a given criterion, typically provided by @point_finder.
  #
  # So we are calculating the hard way what the PST is about to find for us.
  #
  # region: one of :ne, :nw, :three_sided
  # *args: the arguments that specify the bounds of the region.
  #   - when region is :ne or :nw it will be values x0, y0 that specify the corner (x0, y0) of the region
  #   - when region is :three_sided it will be the three values x0, x1, y0 that specify the 3-sided region
  # by: the critereon used to choose the "best" point in the region
  #   - :min_x, max_x
  #   - :max_y or :min_y, with ties broken in favor of smaller values of x
  #   - :all, which isn't a criterion at all. We take all the points in the region and make a set from them. This is useful when
  #     testing an 'enumerate' method.
  # is_min_pst: are we working for a MinPST. Default is false
  # among: if given, look among these points instead of @point_finder. It can be either another PointFinder or just an enumerable of
  #        points
  private def best_in(region, *args, by: :all, is_min_pst: false, among: nil, open: false)
    point_finder = open ? @open_point_finder : @point_finder
    if among
      point_finder = if among.is_a? PointFinder
                       among
                     else
                       PointFinder.new(among, open:)
                     end
    end

    data = case region.to_sym
           when :ne
             point_finder.ne_quadrant(*args)
           when :nw
             point_finder.nw_quadrant(*args)
           when :se
             point_finder.se_quadrant(*args)
           when :sw
             point_finder.sw_quadrant(*args)
           when :three_sided
             x0, x1, y0 = args
             if is_min_pst
               point_finder.three_sided_down(x0, x1, y0)
             else
               point_finder.three_sided_up(x0, x1, y0)
             end
           else
             raise "can't handle region #{region}"
           end

    value = case by.to_sym
            when :min_x
              data.min_by(&:x)
            when :max_x
              data.max_by(&:x)
            when :max_y
              data.max_by { |p| [p.y, -p.x] } # tie broken in favor of smallest x
            when :min_y
              data.min_by { |p| [p.y, p.x] } # tie broken in favor of smallest x
            when :all
              Set.new data
            else
              raise "can't handle selection criterion #{by}"
            end

    if value.nil?
      # Region is empty. We find the correct default value

      # Do it assuming we're working with a MaxPST, and flip afterwards if necessary
      value = if region == :three_sided
                Point.new(INFINITY, -INFINITY)
              elsif by == :max_x
                Point.new(-INFINITY, INFINITY)
              elsif by == :min_x
                Point.new(INFINITY, INFINITY)
              elsif by == :max_y || by == :min_y
                y = -INFINITY
                x = if [:nw, :sw].include? region
                      -INFINITY
                    else
                      INFINITY
                    end
                Point.new(x, y)
              end
      value = Point.new(value.x, -value.y) if is_min_pst
    end
    value
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

  # A little class to filter points that are in a particular region. This does much of the work of a PST in a very slow way and is
  # used when testing results returned by a PST
  class PointFinder
    # Doesn't respect delete!
    attr_reader :points
    attr_reader :min_x, :max_x

    # open: whether the region is open or closed
    def initialize(points, open: false)
      @points = points.clone
      @points_by_x = points.sort_by(&:x)
      @min_x, @max_x = @points_by_x.map(&:x).minmax
      @deletions = []
      @open = open
    end

    # Declare the given point deleted. We don't actually check it is in the set of points we are monitoring
    def delete!(point)
      @deletions << point
    end

    # Forget all deletions
    def clear!
      @deletions = []
    end

    def ne_quadrant(x0, y0)
      if @open
        rightward_points(x0).select { |pair| pair.x != x0 && pair.y > y0 }
      else
        rightward_points(x0).select { |pair| pair.y >= y0 }
      end
    end

    def nw_quadrant(x0, y0)
      if @open
        leftward_points(x0).select { |pair| pair.x != x0 && pair.y > y0 }
      else
        leftward_points(x0).select { |pair| pair.y >= y0 }
      end
    end

    def se_quadrant(x0, y0)
      if @open
        rightward_points(x0).select { |pair| pair.x != x0 && pair.y < y0 }
      else
        rightward_points(x0).select { |pair| pair.y <= y0 }
      end
    end

    def sw_quadrant(x0, y0)
      if @open
        leftward_points(x0).select { |pair| pair.x != x0 && pair.y < y0 }
      else
        leftward_points(x0).select { |pair| pair.y <= y0 }
      end
    end

    def three_sided_up(x0, x1, y0)
      if @open
        ne_quadrant(x0, y0).reject { |pt| pt.x >= x1 }
      else
        ne_quadrant(x0, y0).reject { |pt| pt.x > x1 }
      end
    end

    def three_sided_down(x0, x1, y0)
      if @open
        se_quadrant(x0, y0).reject { |pt| pt.x => x1 }
      else
        se_quadrant(x0, y0).reject { |pt| pt.x > x1 }
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

  # Yield to the block while in "dynamic" context. We check correct return values against the @dynamic_point_finder
  private def dynamic_context
    old_point_finder = @point_finder
    @point_finder = @dynamic_point_finder

    yield

    @point_finder = old_point_finder
  end
end
