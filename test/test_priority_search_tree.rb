require 'byebug'
require 'must_be'
require 'set'
require 'test/unit'
require 'timeout'
require 'ruby-prof'

require 'data_structures_rmolinari'

# Tests for MaxPrioritySearchTree
#
# There are also some tests for the related MinPriortySearchTree, but we have less coverage. The Min version is just a wrapper
# around the Max version.
class PrioritySearchTreeTest < Test::Unit::TestCase
  Point = Shared::Point
  InternalLogicError = Shared::InternalLogicError

  MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
  MinPrioritySearchTree = DataStructuresRMolinari::MinPrioritySearchTree

  INFINITY = Shared::INFINITY

  MAX_PST_QUADRANT_CALLS = %i[largest_y_in_ne largest_y_in_nw smallest_x_in_ne largest_x_in_nw].freeze
  MIN_PST_QUADRANT_CALLS = %i[smallest_y_in_se smallest_y_in_sw smallest_x_in_se largest_x_in_sw].freeze
  ALL_MAX_PST_CALLS = MAX_PST_QUADRANT_CALLS + %i[largest_y_in_3_sided enumerate_3_sided].freeze

  def setup
    @size = (ENV['test_size'] || 10_000).to_i
    @common_raw_data = raw_data(@size)
  end

  # A pair of a real PST and a corresponding simple one that we can use to check the real one against.
  class PSTPair
    extend Forwardable

    attr_reader :pst, :simple_pst

    def_delegators :@pst, :empty?
    def_delegators :@simple_pst, :min_x, :max_x, :min_y, :max_y

    def initialize(pst, simple_pst)
      @pst = pst
      @simple_pst = simple_pst
    end

    def empty?
      @pst.empty?
    end

    # delete top from both PSTs and return the deleted value
    def delete_top!
      top = @pst.delete_top!
      @simple_pst.delete!(top)
      top
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
    MAX_PST_QUADRANT_CALLS.each do |method|
      [true, false].each do |open|
        check_quadrant_calc(max_pst_pair, method, open:)
      end
    end
  end

  def test_max_pst_3_sided_calls
    [true, false].each do |open|
      check_3_sided_calc(max_pst_pair, :largest_y_in_3_sided, open:)
    end
  end

  def test_max_pst_enumerate_3_sided_calls
    [true, false].each do |open|
      [true, false].each do |enumerate_via_block|
        check_3_sided_calc(max_pst_pair, :enumerate_3_sided, open:, enumerate_via_block:)
      end
    end
  end

  ##############################
  # ...and for the "dynamic" version

  def test_dynamic_quadrant_calls
    MAX_PST_QUADRANT_CALLS.each do |method|
      before_and_after_deletion_pair do |pst_pair|
        check_quadrant_calc(pst_pair, method)
      end
    end
  end

  def test_dynamic_3_sided_calls
    before_and_after_deletion_pair do |pst_pair|
      check_3_sided_calc(pst_pair, :largest_y_in_3_sided)
    end
  end

  def test_dynamic_enumerate_3_sided_calls
    [true, false].each do |open|
      [true, false].each do |enumerate_via_block|
        before_and_after_deletion_pair do |pst_pair|
          check_3_sided_calc(pst_pair, :enumerate_3_sided, open:, enumerate_via_block:)
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
    MIN_PST_QUADRANT_CALLS.each do |method|
      [true, false].each do |open|
        check_quadrant_calc(min_pst_pair, method, open:)
      end
    end
  end

  def test_min_pst_3_sided_calls
    [true, false].each do |open|
      check_3_sided_calc(min_pst_pair, :smallest_y_in_3_sided, open:)
    end
  end

  def test_min_pst_enumerate_3_sided_calls
    [true, false].each do |open|
      [true, false].each do |enumerate_via_block|
        check_3_sided_calc(min_pst_pair, :enumerate_3_sided, open:, enumerate_via_block:)
      end
    end
  end

  ########################################
  # Some regression tests on inputs found to be bad during testing

  def test_bad_inputs_for_max_smallest_x_in_ne
    check_one_case(
      :smallest_x_in_ne,
      [[6, 19], [9, 18], [15, 17], [2, 16], [11, 13], [16, 12], [19, 10], [4, 6], [8, 15], [10, 7],
       [12, 11], [13, 9], [14, 4], [17, 2], [18, 3], [1, 5], [3, 1], [5, 8], [7, 14]],
      4, 15,
      Point.new(6, 19)
    )
  end

  def test_bad_inputs_for_max_largest_y_in_3_sided
    [
      # Early versions of code couldn't even handle this!
      [[[1, 1]], 0, 1, 0, Point.new(1, 1)],

      [[[4, 5], [1, 4], [5, 2], [2, 1], [3, 3]],                         2, 3, 2, Point.new(3, 3)],
      [[[8, 8], [1, 7], [6, 5], [2, 6], [4, 3], [5, 1], [7, 2], [3, 4]], 3, 5, 0, Point.new(3, 4)],
      [[[7, 8], [1, 5], [5, 7], [2, 3], [4, 1], [6, 6], [8, 4], [3, 2]], 3, 4, 1, Point.new(3, 2)]
    ].each do |data, *method_params, actual_highest|
      check_one_case(
        :largest_y_in_3_sided,
        data, *method_params, actual_highest
      )
    end
  end

  def test_bad_inputs_for_max_enumerate_3_sided
    # required to handle the optional open: parameter
    check_one = lambda do |data, *method_params, actual_vals, open: false|
      actual_set = Set.new(actual_vals.map { |x, y| Point.new(x, y) })
      check_one_case(:enumerate_3_sided, data, *method_params, actual_set, open:)
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
    check_one_case(:largest_x_in_nw, [[3, 6], [2, 5], [6, 3], [1, 1], [4, 4], [5, 2]], 5, 2, Point.new(5, 2))
  end

  def test_bad_inputs_for_largest_y_in_nw
    check_one_case(:largest_y_in_nw, [[3, 3], [2, 2], [1, 2]], 2, 1, Point.new(1, 2))
  end

  def test_bad_inputs_for_largest_y_in_ne
    check_one_case(:largest_y_in_ne, [[1, 3], [2, 2], [3, 1]], 2, 1, Point.new(2, 2))
  end

  def test_bad_inputs_for_dynamic_largest_x_in_nw
    check_one_dynamic_case(
      :largest_x_in_nw,
      [[7, 5], [9, 3], [5, 8], [2, 2], [8, 5], [6, 7], [1, 7], [10, 10], [4, 4], [3, 1]],
      9, 1,
      [[10, 10], [5, 8], [1, 7], [6, 7], [7, 5], [8, 5], [4, 4], [9, 3], [2, 2], [3, 1]],
      [-INFINITY, INFINITY]
    )
  end

  def test_bad_inputs_for_dynamic_enumerate_3_sided
    check_one_dynamic_case(:enumerate_3_sided, [[2, 2], [1, 2], [3, 2]], 3, 3, 2, [[1, 2]], [[3, 2]])
    check_one_dynamic_case(:enumerate_3_sided, [[1, 3], [3, 2], [2, 2]], 1, 2, 2, [[1, 3]], [[2, 2]])
    check_one_dynamic_case(:enumerate_3_sided, [[1, 3], [2, 3], [3, 3]], 1, 1, 3, [[1, 3]], [])
  end

  private def check_one_case(method, data, *method_params, expected_val, klass: MaxPrioritySearchTree, open: false)
    calculated_val = Timeout.timeout(timeout_time_s) do
      pst = klass.new(data.map { |x, y| Point.new(x, y) })
      calculated_val = pst.send(method, *method_params, open:)
    end
    assert_equal expected_val, calculated_val
  end

  private def check_one_dynamic_case(method, points, *method_params, deleted_points, expected_val, klass: MaxPrioritySearchTree)
    points.map! { Point.new(*_1) }
    deleted_points = Set.new(deleted_points.map { Point.new(*_1) })
    expected_result = if expected_val.empty? || expected_val.first.is_a?(Enumerable)
                        Set.new(expected_val.map { Point.new(*_1) })
                      else
                        Point.new(*expected_val)
                      end

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
  # They are all no-ops unless the environment variable find_bad is sety

  BAD_INPUT_SEARCH_ATTEMPT_LIMIT = 1_000

  def test_find_bad_inputs
    ALL_MAX_PST_CALLS.each do |method|
      search_for_bad_inputs(:max, method) do |points|
        params_for_find_bad_case(points, method)
      end
    end

    search_for_bad_inputs(:max, nil)
  end

  def test_dynamic_find_bad_inputs
    ALL_MAX_PST_CALLS.each do |method|
      search_for_bad_inputs(:max, method) do |points|
        params_for_find_bad_case(points, method, dynamic: true)
      end
    end
  end

  private def params_for_find_bad_case(pairs, method, dynamic: false)
    x_min, x_max = pairs.map(&:x).minmax
    y_min, y_max = pairs.map(&:y).minmax
    x0 = rand(x_min..x_max)
    y0 = rand(y_min..y_max)

    if dynamic
      deletion_count = 0
      loop do
        deletion_count += 1
        break if deletion_count == pairs.size || rand > 0.9
      end
    end

    if method =~ /3_sided/
      x1 = rand(x0..x_max)
      result = { args: [x0, x1, y0] }
    else
      result = { args: [x0, y0] }
    end
    result[:deletion_count] = deletion_count if dynamic
    result
  end

  # Search for a set of bad input that causes klass#method to return the wrong value.
  #
  # If we find such data then output the details to stdout and fail an assertion. Otherwise return true.
  #
  # It is a no-op unless the environment variable find_bad is set
  #
  # - flavor is :max or :min
  # - method is what we call. If it is nil we just construct a PST of the appropriate class with verification turned on.
  #
  # We try BAD_INPUT_SEARCH_ATTEMPT_LIMIT times. On each attempt we generate a list of (x,y) pairs and yield it to a block from
  # which we should receive a hash. It must have a key :args, which are the x and y args we pass to :method. It may also have a key
  # :deletion_count which means two things:
  # - the PST we create is dynamic
  # - before checking the calculation we delete_top! :deletion_count times
  private def search_for_bad_inputs(flavor, method, open: false)
    return unless find_bad_inputs?

    begin
      pairs = params = extra_message = nil

      BAD_INPUT_SEARCH_ATTEMPT_LIMIT.times do
        pairs = raw_data(@size).shuffle
        extra_message = params = nil

        if method
          params = yield(pairs)
          dynamic = params[:deletion_count]
          pst_pair = make_pst_pair(flavor, pairs:, dynamic:)
          if (c = params[:deletion_count])
            deletions = []

            c.times { deletions << pst_pair.delete_top! }
            extra_message = "deletions = [#{deletions.join(', ')}]"
          end
          calculated_value = Timeout.timeout(timeout_time_s) { pst_pair.pst.send(method, *params[:args], open:) }
          expected_value = pst_pair.simple_pst.send(method, *params[:args], open:)
          assert_equal expected_value, calculated_value
        else
          Timeout.timeout(timeout_time_s) { make_pst(flavor, pairs:, verify: true) }
        end
      end
    rescue => e
      # We might get a timeout, a failure in the equality assertion, or an InternalLogicError from the PST code.
      header = case e
               when Timeout::Error
                 "TIMEOUT"
               when Test::Unit::AssertionFailedError
                 "Bad result"
               when InternalLogicError
                 "Logic Error"
               else
                 # This is something else. Reraise it
                 raise
               end

      method_desc = if method
                      "#{method}(#{params[:args].join(', ')}, open: #{open})"
                    else
                      "Constructor"
                    end

      puts "*\n*\n* >>>>>>> #{header} in #{method_desc}.<<<<<<<<*\n*\n#{e.message}"

      pair_data = pairs.map { |p| "[#{p.x},#{p.y}]" }.join(', ')
      puts "points = [#{pair_data}]"
      puts "extra: #{extra_message}" if extra_message
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
    @max_pst_pair ||= make_pst_pair(:max)
  end

  private def min_pst_pair
    @min_pst_pair ||= make_pst_pair(:min)
  end

  private def dynamic_max_pst_pair
    if !@dynamic_max_pst_pair || @dynamic_max_pst_pair.empty?
      @dynamic_max_pst_pair = make_pst_pair(:max, dynamic: true)
    end
    @dynamic_max_pst_pair
  end

  private def make_pst_pair(flavor, pairs: @common_raw_data.shuffle, dynamic: false)
    PSTPair.new(
      make_pst(flavor, pairs:, dynamic:, verify: false),
      SimplePrioritySearchTree.new(pairs.clone)
    )
  end

  private def make_pst(flavor, pairs: @common_raw_data.shuffle, dynamic: false, verify: false)
    case flavor
    when :max
      MaxPrioritySearchTree.new(pairs.clone, dynamic:, verify:)
    when :min
      MinPrioritySearchTree.new(pairs.clone, dynamic:, verify:)
    else
      raise "Unknown flavor #{flavor.inspect}"
    end
  end

  # Check that a PST calculation in a quadrant gives the correct result
  #
  # - pst_pair: a PST/SimplePst pair used to perform the calculation and check the result
  # - method: the method to call on the PSTs
  # - open: is the region open or closed?
  private def check_quadrant_calc(pst_pair, method, open: false)
    100.times do
      x0 = rand(pst_pair.min_x..pst_pair.max_x)
      y0 = rand(pst_pair.min_y..pst_pair.max_y)
      check_calculation(pst_pair, method, x0, y0, open:)
    end
  end

  # Check that a PST calculation in a three sided region gives the correct result
  #
  # - pst_pair: a PST/SimplePst pair used to perform the calculation and check the result
  # - method: the method to call on the PSTs
  # - enumerate_via_block: should the calculation yield to a block?
  #   - if so, we check that the right elements are yielded
  # - open: is the region open or closed?
  private def check_3_sided_calc(pst_pair, method, enumerate_via_block: false, open: false)
    100.times do
      x0 = rand(pst_pair.min_x..pst_pair.max_x)
      x1 = rand(x0..pst_pair.max_x)
      y0 = rand(pst_pair.min_y..pst_pair.max_y)
      check_calculation(pst_pair, method, x0, x1, y0, enumerate_via_block:, open:)
    end
  end

  private def check_calculation(pst_pair, method, *args, enumerate_via_block: false, open: false)
    is_min = pst_pair.pst.is_a?(MinPrioritySearchTree)

    tag = "#{method}(#{args.join(', ')}) #{'/open' if open} #{'/enumerate_via_block' if enumerate_via_block}"

    # This is a wart.
    #
    # We don't need it for smallest_y_in_3_sided becasuse we know that it must be for a MinPST.
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

    # for_min_pst: is a wart. Since we aren't either a MinPST or a MaxPST, we need to know which one we are emulating.
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

      first_idx = @points_by_x.bsearch_index { |v| v.x >= x0 }
      points = @points_by_x[first_idx..]
      points - @deletions
    end

    # Points (x,y) in @data with x <= x0
    private def leftward_points(x0)
      return [] if points.empty?

      first_bad_idx = @points_by_x.bsearch_index { |v| v.x > x0 }
      points = @points_by_x[...first_bad_idx]
      points - @deletions
    end
  end
end
