require 'test/unit'
begin
  require 'byebug'
rescue LoadError
  # optional dev dependency
end
require 'must_be'

require 'data_structures_rmolinari'

SegmentTree = DataStructuresRMolinari::SegmentTree

class SegmentTreeTest < Test::Unit::TestCase
  DATA = [
      -1, 7, 1, -4, 3, 0, -4, 1, -8, 9, -5, -10, 4, -9, 3, 8, 3, 6, 7, 1, -4, 8, -9, -6, 10, -10, 7, 9, -6, -10, 5, -4, -1, -2, 4,
      3, -10, -8, 9, 2
    ]

  def test_max_val_segment_tree
    seg_tree = make_one(:max, :ruby, DATA)
    test_seg_tree_basic(seg_tree, :max_on, DATA.size) { |i, j| DATA[i..j].max }
  end

  def test_max_val_segment_tree_updates
    mutable_data = DATA.clone
    seg_tree = make_one(:max, :ruby, mutable_data)
    test_seg_tree_with_updates(seg_tree, :max_on, mutable_data) { |i, j| mutable_data[i..j].max }
  end

  def test_index_of_max_val_segment_tree
    seg_tree = make_one(:index_of_max, :ruby, DATA)
    test_seg_tree_basic(seg_tree, :index_of_max_val_on, DATA.size) { |i, j| (i..j).max_by { DATA[_1] } }
  end

  def test_index_of_max_val_segment_tree_updates
    mutable_data = DATA.clone
    seg_tree = make_one(:index_of_max, :ruby, mutable_data)
    test_seg_tree_with_updates(seg_tree, :index_of_max_val_on, mutable_data) { |i, j| (i..j).max_by { mutable_data[_1] } }
  end

  def test_first_prefix_sum_c_fixnum_fast_path
    assert_first_prefix_sum_for_lang(:c)
  end

  def test_first_prefix_sum_ruby_template
    assert_first_prefix_sum_for_lang(:ruby)
  end

  def test_find_leftmost_on_segment_tree_template_ruby
    data = [2, 0, 5, 1, 3]
    template = DataStructuresRMolinari::SegmentTree::SegmentTreeTemplate.new(
      combine:               ->(a, b) { a + b },
      single_cell_array_val: ->(i) { data[i] },
      size:                  data.size,
      identity:              0
    )
    assert_prefix_sum_search(template, data)
  end

  def test_find_leftmost_c_generic_sum_path
    data = [1, 2**100, 3]
    refute SegmentTree.fixnum_fast_path_data?(data)
    sum_tree = SegmentTree.construct(data, :sum, :c)
    assert_equal 0, sum_tree.index_of_first_large_prefix_sum(1)
    assert_equal 1, sum_tree.index_of_first_large_prefix_sum(2)
    assert_equal 1, sum_tree.index_of_first_large_prefix_sum(2**100)
    assert_equal 2, sum_tree.index_of_first_large_prefix_sum(2**100 + 4)
    assert_nil sum_tree.index_of_first_large_prefix_sum(2**100 + 5)
  end

  def test_find_leftmost_max_prefix_ruby_and_c
    data = [1, 5, 2, 8, 3]
    prefix_max = []
    running = -Float::INFINITY
    data.each do |v|
      running = [running, v].max
      prefix_max << running
    end

    [:ruby, :c].each do |lang|
      tree = make_one(:max, lang, data.dup)
      structure = tree.instance_variable_get(:@structure)
      (0..20).each do |target|
        expected = prefix_max.index { _1 >= target }
        actual = structure.find_leftmost_by_prefix(0, data.size - 1, threshold: target, compare: :ge)
        assert_equal expected, actual, "lang=#{lang} target=#{target}"
      end
    end
  end

  def test_find_leftmost_custom_compare_proc_ruby_only
    data = [1, 2, 3, 4]
    template = DataStructuresRMolinari::SegmentTree::SegmentTreeTemplate.new(
      combine:               ->(a, b) { a + b },
      single_cell_array_val: ->(i) { data[i] },
      size:                  data.size,
      identity:              0
    )
    assert_equal 3, template.find_leftmost_by_prefix(0, 3, threshold: 6, compare: ->(agg, t) { agg > t })
  end

  def test_find_leftmost_custom_compare_proc_c_generic_delegates_to_ruby
    data = [1, 2**100, 3]
    structure = SegmentTree.construct(data, :sum, :c).instance_variable_get(:@structure)
    assert_equal 1, structure.find_leftmost_by_prefix(0, 2, threshold: 2, compare: ->(agg, t) { agg >= t })
  end

  def test_find_leftmost_custom_compare_rejected_on_c_fixnum
    data = [1, 2, 3]
    structure = SegmentTree.construct(data, :sum, :c).instance_variable_get(:@structure)
    assert_raises(ArgumentError) do
      structure.find_leftmost_by_prefix(0, 2, threshold: 2, compare: ->(agg, t) { agg >= t })
    end
  end

  def test_find_leftmost_after_update_c
    data = [1, 2, 3, 4]
    tree = make_one(:sum, :c, data)
    data[0] = 10
    tree.update_at(0)
    assert_equal 0, tree.index_of_first_large_prefix_sum(10)
    assert_equal 1, tree.index_of_first_large_prefix_sum(11)
    assert_nil tree.index_of_first_large_prefix_sum(20)
  end

  ########################################
  # C implementation

  def test_max_val_segment_tree_with_c
    seg_tree = make_one(:max, :c, DATA)
    test_seg_tree_basic(seg_tree, :max_on, DATA.size) { |i, j| DATA[i..j].max }
  end

  def test_max_val_segment_tree_updates_with_c
    mutable_data = DATA.clone
    seg_tree = make_one(:max, :c, mutable_data)
    test_seg_tree_with_updates(seg_tree, :max_on, mutable_data) { |i, j| mutable_data[i..j].max }
  end

  def test_index_of_max_val_segment_tree_with_c
    seg_tree = make_one(:index_of_max, :c, DATA)
    test_seg_tree_basic(seg_tree, :index_of_max_val_on, DATA.size) { |i, j| (i..j).max_by { DATA[_1] } }
  end

  def test_index_of_max_val_segment_tree_updates_with_c
    mutable_data = DATA.clone
    seg_tree = make_one(:index_of_max, :c, mutable_data)
    test_seg_tree_with_updates(seg_tree, :index_of_max_val_on, mutable_data) { |i, j| (i..j).max_by { mutable_data[_1] } }
  end

  def test_sum_segment_tree_with_c
    seg_tree = make_one(:sum, :c, DATA)
    test_seg_tree_basic(seg_tree, :sum_on, DATA.size) { |i, j| DATA[i..j].sum }
  end

  def test_sum_segment_tree_updates_with_c
    mutable_data = DATA.clone
    seg_tree = make_one(:sum, :c, mutable_data)
    test_seg_tree_with_updates(seg_tree, :sum_on, mutable_data) { |i, j| mutable_data[i..j].sum }
  end

  def test_min_val_segment_tree_ruby
    seg_tree = make_one(:min, :ruby, DATA)
    test_seg_tree_basic(seg_tree, :min_on, DATA.size) { |i, j| DATA[i..j].min }
  end

  def test_min_val_segment_tree_with_c
    seg_tree = make_one(:min, :c, DATA)
    test_seg_tree_basic(seg_tree, :min_on, DATA.size) { |i, j| DATA[i..j].min }
  end

  def test_min_val_segment_tree_updates_with_c
    mutable_data = DATA.clone
    seg_tree = make_one(:min, :c, mutable_data)
    test_seg_tree_with_updates(seg_tree, :min_on, mutable_data) { |i, j| mutable_data[i..j].min }
  end

  SMALL_PRODUCT_DATA = [1, 2, 3, -1, 4, 2].freeze

  def test_product_segment_tree_ruby
    seg_tree = make_one(:product, :ruby, SMALL_PRODUCT_DATA.dup)
    test_seg_tree_basic(seg_tree, :product_on, SMALL_PRODUCT_DATA.size) { |i, j| SMALL_PRODUCT_DATA[i..j].reduce(:*) }
  end

  def test_product_segment_tree_with_c
    seg_tree = make_one(:product, :c, SMALL_PRODUCT_DATA.dup)
    test_seg_tree_basic(seg_tree, :product_on, SMALL_PRODUCT_DATA.size) { |i, j| SMALL_PRODUCT_DATA[i..j].reduce(:*) }
  end

  def test_product_segment_tree_updates_with_c
    mutable = SMALL_PRODUCT_DATA.dup
    seg_tree = make_one(:product, :c, mutable)
    test_seg_tree_with_updates(seg_tree, :product_on, mutable) { |i, j| mutable[i..j].reduce(:*) }
  end

  HASH_BACKING = { 0 => -1, 1 => 7, 2 => 1, 3 => -4, 4 => 3 }.freeze

  def test_max_val_segment_tree_hash_backing_ruby
    seg_tree = make_one(:max, :ruby, HASH_BACKING)
    test_seg_tree_basic(seg_tree, :max_on, HASH_BACKING.size) { |i, j| (i..j).map { HASH_BACKING[_1] }.max }
  end

  def test_min_val_segment_tree_hash_backing_ruby
    seg_tree = make_one(:min, :ruby, HASH_BACKING)
    test_seg_tree_basic(seg_tree, :min_on, HASH_BACKING.size) { |i, j| (i..j).map { HASH_BACKING[_1] }.min }
  end

  def test_max_val_indexed_proc_backing_ruby
    ary = [2, 0, 5, 1, 3]
    backing = SegmentTree.indexed_proc(ary.size) { |i| ary[i] }
    seg_tree = SegmentTree.construct(backing, :max, :ruby)
    test_seg_tree_basic(seg_tree, :max_on, ary.size) { |i, j| ary[i..j].max }
  end

  def test_min_val_indexed_proc_backing_updates_ruby
    ary = DATA.take(10).dup
    backing = SegmentTree.indexed_proc(ary.size) { |i| ary[i] }
    seg_tree = SegmentTree.construct(backing, :min, :ruby)
    test_seg_tree_with_updates(seg_tree, :min_on, ary) { |i, j| ary[i..j].min }
  end

  def test_fixnum_fast_path_data_predicate
    assert_equal(true, SegmentTree.fixnum_fast_path_data?(DATA))
    assert_equal(false, SegmentTree.fixnum_fast_path_data?([1, 2**100, 3]))
    assert_equal(false, SegmentTree.fixnum_fast_path_data?('not an array'))
  end

  def test_c_product_overflow_raises
    big = (1 << 40)
    data = [big, big]
    assert_raises(RangeError) { SegmentTree.construct(data, :product, :c) }
  end

  def test_c_max_generic_path_with_bignum_element
    data = [1, 2**100, 3]
    seg_tree = SegmentTree.construct(data, :max, :c)
    assert_equal(2**100, seg_tree.max_on(0, 2))
    assert_equal(1, seg_tree.max_on(0, 0))
  end

  ########################################
  # Helpers

  private def test_seg_tree_basic(seg_tree, method, data_size, &block)
    check_all_intervals(seg_tree, method, data_size) { |i, j| block.call(i, j) }
  end

  private def test_seg_tree_with_updates(seg_tree, method, mutable_data, &block)
    (0...(mutable_data.size)).each do |idx|
      mutable_data[idx] += rand(-5..5)
      seg_tree.update_at(idx)
      check_all_intervals(seg_tree, method, mutable_data.size) { |i, j| block.call(i, j) }
    end
  end

  private def check_all_intervals(segment_tree, method, data_size)
    (0...data_size).each do |i|
      (i...data_size).each do |j|
        expected_value = yield(i, j)
        actual_value = segment_tree.send(method, i, j)
        assert_equal expected_value, actual_value
      end
    end
  end

  private def make_one(op, lang, data)
    SegmentTree.construct(data, op, lang)
  end

  private def assert_first_prefix_sum_for_lang(lang)
    data_size = 100
    data = (0...data_size).to_a.shuffle
    prefix_sums = []
    running_sum = 0
    (0...data_size).each do |i|
      running_sum += data[i]
      prefix_sums << running_sum
    end

    seg_tree = make_one(:sum, lang, data)
    (0..4050).each do |target|
      expected_value = prefix_sums.bsearch_index { _1 >= target }
      actual_value = seg_tree.index_of_first_large_prefix_sum(target)
      assert_equal expected_value, actual_value, "lang=#{lang} target=#{target}"
    end
  end

  # Upper bound for iterating targets by numeric value. Without this, (0..prefix_total+5) can be astronomically
  # large when prefix sums use Bignums (e.g. 2**100), causing a near-infinite loop at 100% CPU.
  MAX_PREFIX_SEARCH_TARGET_ITERATION = 20_000

  private def assert_prefix_sum_search(template, data)
    prefix_sums = []
    running = 0
    data.each do |v|
      running += v
      prefix_sums << running
    end
    last = prefix_sums.last || 0
    upper = [last + 5, MAX_PREFIX_SEARCH_TARGET_ITERATION].min
    (0..upper).each do |target|
      expected = prefix_sums.index { _1 >= target }
      actual = template.find_leftmost_by_prefix(0, data.size - 1, threshold: target, compare: :ge)
      assert_equal expected, actual, "target=#{target}"
    end
  end

  private def assert_prefix_sum_search_on_sum_tree(sum_tree, data, max_target: nil)
    prefix_sums = []
    running = 0
    data.each { |v| running += v; prefix_sums << running }
    natural = (prefix_sums.last || 0) + 5
    upper = max_target || [natural, MAX_PREFIX_SEARCH_TARGET_ITERATION].min
    (0..upper).each do |target|
      expected = prefix_sums.index { _1 >= target }
      actual = sum_tree.index_of_first_large_prefix_sum(target)
      assert_equal expected, actual, "target=#{target}"
    end
  end
end
