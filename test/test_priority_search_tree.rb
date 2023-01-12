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

Point = Shared::Point
InternalLogicError = Shared::InternalLogicError

MaxPrioritySearchTree = DataStructuresRMolinari::MaxPrioritySearchTree
MinPrioritySearchTree = DataStructuresRMolinari::MinPrioritySearchTree

class PrioritySearchTreeTest < Test::Unit::TestCase
  INFINITY = Float::INFINITY

  def setup
    @size = (ENV['test_size'] || 100_000).to_i
    @pairs_by_x = raw_data(@size)
    @pairs_by_y = @pairs_by_x.sort_by(&:y)
    @min_x, @max_x = @pairs_by_x.map(&:x).minmax
  end

  ########################################
  # Tests for the (vanilla) MaxPST

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

  def test_max_pst_largest_y_in_nw
    check_quadrant_calc(max_pst, :max, :y, :nw)
  end

  def test_max_pst_smallest_x_in_ne
    check_quadrant_calc(max_pst, :min, :x, :ne)
  end

  def test_max_pst_largest_x_in_nw
    check_quadrant_calc(max_pst, :max, :x, :nw)
  end

  def test_max_pst_largest_y_in_3_sided
    check_3_sided_calc(max_pst, :max, :y)
  end

  def test_max_pst_enumerate_3_sided
    check_3_sided_calc(max_pst, :all, nil)
  end

  ########################################
  # Tests for the MinPST

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
  end

  ########################################
  # Some regression tests on inputs found to be bad during testing

  private def check_one_case(klass, method, data, *method_params, expected_val)
    calculated_val = Timeout::timeout(timeout_time_s) do
      pst = klass.new(data.map { |x, y| Point.new(x, y) })
      calculated_val = pst.send(method, *method_params)
    end
    assert_equal expected_val, calculated_val
  end

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

  ########################################
  # Some quasi-tests that search for inputs that lead to assertion failures.
  #
  # They are all no-ops unless the environment variable find_bad is set

  BAD_INPUT_SEARCH_ATTEMPT_LIMIT = 1_000

  def test_max_find_bad_input_for_smallest_x_in_ne
    search_for_bad_inputs(MaxPrioritySearchTree, :smallest_x_in_ne) do |pairs|
      x0 = rand(@size)
      y0 = rand(@size)
      actual_leftmost = pairs.select { |p| p.x >= x0 && p.y >= y0 }.min_by(&:x) || Point.new(INFINITY, INFINITY)

      [[x0, y0], actual_leftmost]
    end
  end

  def test_max_find_bad_input_for_largest_y_in_3_sided
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_3_sided) do |pairs|
      x0 = rand(@size)
      x1 = x0 + 1 + rand(@size - x0)
      y0 = rand(@size)
      actual_highest = pairs.select { |p| x0 <= p.x && p.x <= x1 && p.y >= y0 }.max_by{ |p| [p.y, -p.x] } || Point.new(INFINITY, -INFINITY)

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

  def test_max_find_bad_input_for_largest_x_in_nw
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_x_in_nw) do |pairs|
      x0 = rand(@size)
      y0 = rand(@size)
      actual_rightmost = pairs.select { |p| p.x <= x0 && p.y >= y0 }.max_by(&:x) || Point.new(-INFINITY, INFINITY)

      [[x0, y0], actual_rightmost]
    end
  end

  def test_max_find_bad_input_for_largest_y_in_ne
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_ne) do |pairs|
      x0 = rand(@size)
      y0 = rand(@size)
      actual_highest = pairs.select { |p| p.x >= x0 && p.y >= y0 }.max_by{ |p| [p.y, -p.x] } || Point.new(INFINITY, -INFINITY)

      [[x0, y0], actual_highest]
    end
  end

  def test_max_find_bad_input_for_largest_y_in_nw
    search_for_bad_inputs(MaxPrioritySearchTree, :largest_y_in_nw) do |pairs|
      x0 = rand(@size)
      y0 = rand(@size)
      actual_highest = pairs.select { |p| p.x <= x0 && p.y >= y0 }.max_by{ |p| [p.y, -p.x] } || Point.new(-INFINITY, -INFINITY)

      [[x0, y0], actual_highest]
    end
  end

  def test_max_find_bad_input_for_construction
    search_for_bad_inputs(MaxPrioritySearchTree, nil) do |pairs|
      nil
    end
  end

  ########################################
  # Harness for profiling
  #
  # These aren't actually tests and make no assertions. THey do nothing unless the >profile< environment variable is set.

  def test_profiling
    method = :enumerate_3_sided
    profile(method) do
      pst = MaxPrioritySearchTree.new(@pairs_by_x.shuffle)
      100.times do
        x0 = rand(@size)
        x1 = rand(@size - x0) + x0
        y0 = rand(@size)
        pst.send(method, x0, x1, y0)
      end
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
  # If method.nil? we just call the constructor, but with verification turned on
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

      timeout = false
      error_message = nil
      begin
        if method
          pst = klass.new(pairs.clone)
          calculated_value = Timeout::timeout(timeout_time_s) {
            pst.send(method, *method_params)
          }
        else
          pst = klass.new(pairs.clone, verify: true)
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
        puts "params = [#{method_params.join(', ')}]"
        puts "data = [#{pair_data}]"

        assert_equal expected_value, calculated_value
      else
        puts "data = [#{pair_data}]"

        assert false
      end
    end
    puts "No bad data found for #{klass}##{method}"
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
    @max_pst ||= MaxPrioritySearchTree.new(@pairs_by_x.shuffle)
  end

  private def min_pst
    @min_pst ||= MinPrioritySearchTree.new(@pairs_by_x.shuffle)
  end

  # Check that a MaxPST calculation in a quadrant gives the correct result
  #
  # - criterion: :min or :max
  # - dimension: :x or :y
  # - region: :ne or :nw
  private def check_quadrant_calc(pst, criterion, dimension, region)
    criterion.must_be_in [:min, :max]
    dimension.must_be_in [:x, :y]
    region.must_be_in [:ne, :nw, :se, :sw]

    100.times do
      x0 = rand(@size)
      y0 = rand(@size)
      check_calculation(pst, criterion, dimension, region, x0, y0)
    end
  end

  # Check that a MaxPST calculation in a three sided region gives the correct result
  #
  # - criterion: :max or :all
  # - dimension: :y or nil
  private def check_3_sided_calc(pst, criterion, dimension)
    criterion.must_be_in [:min, :max, :all]
    dimension.must_be :y if dimension

    100.times do
      x0 = rand(@size)
      x1 = rand(x0..@size)
      y0 = rand(@size)
      check_calculation(pst, criterion, dimension, :three_sided, x0, x1, y0)
    end
  end

  # Check that the PST correctly finds the desired point in a stated region
  #
  # property: :min, :max, or :all (for enumerate)
  # dimension: the dimension we are "optimizing", :x or :y, ignored when property is :all
  # region: :ne, :nw, :three_sided
  # args: the args that bound the region
  # default_result: the result to expect when there are no points in the target region
  #
  # TODO: have it work out the default_result itself.
  private def check_calculation(pst, property, dimension, region, *args)
    is_min_pst = pst.is_a? MinPrioritySearchTree

    region.must_be_in [:ne, :nw, :se, :sw, :three_sided]
    dimension.must_be_in [:x, :y, nil]
    property.must_be_in [:min, :max, :all]

    raise 'x-dimension calculations not supported in 3-sided region' if region == :three_sided && dimension == :x
    raise 'dimension must be given unless we are enumerating' if property != :all && !dimension

    # TODO: allow this when we have a MinPST
    if is_min_pst
      raise 'maximizing in the y-dimension is not supported by a MinPST' if property == :max && dimension == :y
    else
      raise 'minimizing in the y-dimension is not supported by a MaxPST' if property == :min && dimension == :y
    end

    # Work out what the "default" value would be if there aren't any points in the region
    default_result = nil
    if property == :all
      method = "enumerate_3_sided"
      criterion = :all
    else
      method_word1 = property == :min ? :smallest : :largest
      method_word2 = dimension
      method_word4 = region == :three_sided ? '3_sided' : region

      method = "#{method_word1}_#{method_word2}_in_#{method_word4}".to_sym
      criterion = "#{property}_#{dimension}".to_sym

      # TODO: do this property for MinPST when we get one
      if region == :three_sided
        default_x = INFINITY
        default_y = -INFINITY
      elsif dimension == :x
        default_y = INFINITY
        default_x = property == :min ? INFINITY : -INFINITY
      elsif dimension == :y
        default_y = -INFINITY
        default_x = if [:nw, :sw].include? region
                      -INFINITY
                    else
                      INFINITY
                    end
      end
      default_y = -default_y if is_min_pst

      default_result = Point.new(default_x, default_y)
    end

    expected = best_in(region, *args, by: criterion) || default_result
    calculated = pst.send(method, *args)
    assert_equal expected, calculated
  end

  # The "best" value in a given region by a given criterion.
  #
  # So we are calculating the hard way what the PST is about to find for us.
  #
  # region: one of :ne, :nw, :three_sided
  # *args: the arguments that specify the bounds of the region.
  #   - when region is :ne or :nw it will be values x0, y0 that specify the corner (x0, y0) of the region
  #   - when region is :three_sided it will be the three values x0, x1, y0 that specify the 3-sided region
  # by: the critereon used to choose the "best" point in the region
  #   - :min_x, max_x
  #   - :max_y, with ties broken in favor of smaller values of x
  #   - :all, which isn't a criterion at all. We take all the points in the region and make a set from them. This is useful when
  #     testing an 'enumerate' method.
  private def best_in(region, *args, by: :all)
    data = case region.to_sym
           when :ne
             ne_quadrant(*args)
           when :nw
             nw_quadrant(*args)
           when :se
             se_quadrant(*args)
           when :sw
             sw_quadrant(*args)
           when :three_sided
             x0, x1, y0 = args
             ne_quadrant(x0, y0).reject { |pair| pair.x > x1 }
           else
             raise "can't handle region #{region}"
           end

    case by.to_sym
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
  end

  # By default we take x values 1, 2, ..., size and choose random integer y values in 1..size.
  #
  # If the environment variable 'floats' is set, instead choose random values in 0..1 for both coordinates.
  private def raw_data(size)
    if ENV['floats']
      (1..size).map { Point.new(rand, rand) }
    else
      list = (1..size).to_a
      y_vals = (1..size).map { rand(1..size)}
      list.zip(y_vals).map { Point.new(*_1) }
    end
  end

  # Points (x,y) in @data with x >= x0
  private def rightward_points(x0)
    return @pairs_by_x if x0 <= @min_x
    return [] if x0 > @max_x

    first_idx = @pairs_by_x.bsearch_index { |v| v.x >= x0 }
    @pairs_by_x[first_idx..]
  end

  # Points (x,y) in @data with x <= x0
  private def leftward_points(x0)
    return @pairs_by_x if x0 >= @max_x
    return [] if x0 < @min_x

    first_idx = @pairs_by_x.bsearch_index { |v| v.x >= x0 }
    if @pairs_by_x[first_idx].x == x0
      @pairs_by_x[..first_idx]
    else
      @pairs_by_x[...first_idx]
    end
  end

  private def ne_quadrant(x0, y0)
    rightward_points(x0).select { |pair| pair.y >= y0 }
  end

  private def nw_quadrant(x0, y0)
    leftward_points(x0).select { |pair| pair.y >= y0 }
  end

  private def se_quadrant(x0, y0)
    rightward_points(x0).select { |pair| pair.y <= y0 }
  end

  private def sw_quadrant(x0, y0)
    leftward_points(x0).select { |pair| pair.y <= y0 }
  end
end
