/*
 * This is a C implementation of a Segment Tree data structure.
 *
 * More specifically, it is the C version of the SegmentTreeTemplate Ruby class, for which see elsewhere in the repo.
 *
 * When built with c_initialize_fixnum (see Init), the tree stores aggregated numeric values in a long long[] array and
 * performs max/sum/product in C without invoking Ruby procs on the query/update hot path. Leaf reads still use the
 * backing Ruby Array (rb_ary_entry) so update_at sees mutations to that array.
 */

#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include "ruby.h"
#include "shared.h"

typedef enum {
  ST_MODE_GENERIC = 0,
  ST_MODE_FIXNUM_MAX = 1,
  ST_MODE_FIXNUM_SUM = 2,
  ST_MODE_FIXNUM_PROD = 3
} st_mode_t;

typedef struct {
  st_mode_t mode;
  VALUE *tree; /* 1-based implicit tree; generic mode only */
  long long *tree_ll; /* 1-based; fixnum fast paths only */
  VALUE single_cell_array_val_lambda;
  VALUE combine_lambda;
  VALUE identity;
  VALUE data_array; /* retained backing array for fixnum fast path */
  size_t size;
  size_t tree_alloc_size;
} segment_tree_data;

static ID id_call;

static int op_sym_to_mode(VALUE op) {
  Check_Type(op, T_SYMBOL);
  ID id = rb_sym2id(op);
  if (id == rb_intern("max")) return ST_MODE_FIXNUM_MAX;
  if (id == rb_intern("sum")) return ST_MODE_FIXNUM_SUM;
  if (id == rb_intern("product")) return ST_MODE_FIXNUM_PROD;
  rb_raise(rb_eArgError, "unsupported fixnum_op %+" PRIsVALUE, op);
}

static long long fixnum_leaf_ll(VALUE v) {
  if (!RB_FIXNUM_P(v)) {
    rb_raise(rb_eTypeError, "expected Fixnum leaf value, got %+" PRIsVALUE, v);
  }
  return (long long)FIX2LONG(v);
}

#if defined(__GNUC__) || defined(__clang__)
#define ST_HAS_INT_OVERFLOW_BUILTINS 1
#else
#define ST_HAS_INT_OVERFLOW_BUILTINS 0
#endif

static long long combine_ll(st_mode_t mode, long long a, long long b) {
  switch (mode) {
    case ST_MODE_FIXNUM_MAX:
      return a > b ? a : b;
    case ST_MODE_FIXNUM_SUM: {
      long long out;
#if ST_HAS_INT_OVERFLOW_BUILTINS
      if (__builtin_add_overflow(a, b, &out)) {
        rb_raise(rb_eRangeError, "sum overflow in fixnum segment tree");
      }
#else
      out = a + b;
      if (((a ^ b) >= 0) && ((a ^ out) < 0)) {
        rb_raise(rb_eRangeError, "sum overflow in fixnum segment tree");
      }
#endif
      return out;
    }
    case ST_MODE_FIXNUM_PROD: {
      long long out;
#if ST_HAS_INT_OVERFLOW_BUILTINS
      if (__builtin_mul_overflow(a, b, &out)) {
        rb_raise(rb_eRangeError, "product overflow in fixnum segment tree");
      }
#else
      /* No compiler builtins: cannot portably detect signed overflow for all cases. */
      out = a * b;
#endif
      return out;
    }
    default:
      rb_raise(eSharedInternalLogicError, "combine_ll called in unexpected mode %d", (int)mode);
  }
}

static VALUE ll_to_ruby_num(long long v) { return rb_ll2inum(v); }

#define single_cell_val_at(seg_tree, idx) \
  rb_funcall((seg_tree)->single_cell_array_val_lambda, id_call, 1, LONG2FIX((long)(idx)))

#define combined_val(seg_tree, v1, v2) rb_funcall((seg_tree)->combine_lambda, id_call, 2, (v1), (v2))

/************************************************************
 * Memory Management
 */

static segment_tree_data *create_segment_tree(void) {
  segment_tree_data *segment_tree = malloc(sizeof(segment_tree_data));
  if (!segment_tree) {
    rb_raise(rb_eNoMemError, "malloc failed for segment tree");
  }
  memset(segment_tree, 0, sizeof(segment_tree_data));
  segment_tree->mode = ST_MODE_GENERIC;
  segment_tree->single_cell_array_val_lambda = Qnil;
  segment_tree->combine_lambda = Qnil;
  segment_tree->identity = Qnil;
  segment_tree->data_array = Qnil;
  return segment_tree;
}

static void segment_tree_free(void *ptr) {
  if (!ptr) return;
  segment_tree_data *segment_tree = ptr;
  xfree(segment_tree->tree);
  xfree(segment_tree->tree_ll);
  xfree(segment_tree);
}

static size_t segment_tree_memsize(const void *ptr) {
  if (!ptr) return 0;
  const segment_tree_data *st = ptr;
  size_t n = sizeof(segment_tree_data);
  if (st->tree) {
    n += sizeof(VALUE) * st->tree_alloc_size;
  }
  if (st->tree_ll) {
    n += sizeof(long long) * st->tree_alloc_size;
  }
  return n;
}

static void segment_tree_mark(void *ptr) {
  segment_tree_data *st = ptr;

  if (st->mode == ST_MODE_GENERIC) {
    if (!NIL_P(st->combine_lambda)) rb_gc_mark(st->combine_lambda);
    if (!NIL_P(st->single_cell_array_val_lambda)) rb_gc_mark(st->single_cell_array_val_lambda);
    rb_gc_mark(st->identity);

    if (st->tree) {
      for (size_t i = 0; i < st->tree_alloc_size; i++) {
        VALUE value = st->tree[i];
        if (value) {
          rb_gc_mark(value);
        }
      }
    }
  } else {
    rb_gc_mark(st->identity);
    rb_gc_mark(st->data_array);
  }
}

static const rb_data_type_t segment_tree_type = {
  .wrap_struct_name = "segment_tree_template",
  {
      .dmark = segment_tree_mark,
      .dfree = segment_tree_free,
      .dsize = segment_tree_memsize,
  },
  .data = NULL,
  .flags = 0,
};

static segment_tree_data *unwrapped(VALUE self) {
  segment_tree_data *segment_tree;
  TypedData_Get_Struct((self), segment_tree_data, &segment_tree_type, segment_tree);
  return segment_tree;
}

static VALUE segment_tree_alloc(VALUE klass) {
  segment_tree_data *segment_tree = create_segment_tree();
  return TypedData_Wrap_Struct(klass, &segment_tree_type, segment_tree);
}

/************************************************************
 * Generic (lambda-driven) implementation
 */

static void build(segment_tree_data *segment_tree, size_t tree_idx, size_t tree_l, size_t tree_r) {
  if (tree_l == tree_r) {
    segment_tree->tree[tree_idx] = single_cell_val_at(segment_tree, tree_l);
  } else {
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);

    build(segment_tree, left, tree_l, mid);
    build(segment_tree, right, mid + 1, tree_r);

    VALUE comb_val = combined_val(segment_tree, segment_tree->tree[left], segment_tree->tree[right]);
    segment_tree->tree[tree_idx] = comb_val;
  }
}

static void setup(segment_tree_data *seg_tree, VALUE combine, VALUE single_cell_array_val, VALUE size, VALUE identity) {
  if (!rb_obj_respond_to(combine, id_call, TRUE)) {
    rb_raise(rb_eArgError, "wrong type argument %" PRIsVALUE " (should be callable)", rb_obj_class(combine));
  }

  if (!rb_obj_respond_to(single_cell_array_val, id_call, TRUE)) {
    rb_raise(rb_eArgError, "wrong type argument %" PRIsVALUE " (should be callable)", rb_obj_class(single_cell_array_val));
  }

  seg_tree->mode = ST_MODE_GENERIC;
  seg_tree->combine_lambda = combine;
  seg_tree->single_cell_array_val_lambda = single_cell_array_val;
  seg_tree->identity = identity;
  seg_tree->data_array = Qnil;
  seg_tree->size = checked_nonneg_fixnum(size);

  if (seg_tree->size == 0) {
    rb_raise(rb_eArgError, "size must be positive.");
  }

  xfree(seg_tree->tree);
  xfree(seg_tree->tree_ll);
  seg_tree->tree_ll = NULL;

  size_t tree_size = 1 + 4 * seg_tree->size;
  seg_tree->tree = calloc(tree_size, sizeof(VALUE));
  if (!seg_tree->tree) {
    rb_raise(rb_eNoMemError, "calloc failed for segment tree");
  }
  seg_tree->tree_alloc_size = tree_size;

  build(seg_tree, TREE_ROOT, 0, seg_tree->size - 1);
}

static VALUE determine_val(segment_tree_data *seg_tree, size_t tree_idx, size_t left, size_t right, size_t tree_l,
                           size_t tree_r) {
  if (left == tree_l && right == tree_r) {
    return seg_tree->tree[tree_idx];
  }

  size_t mid = midpoint(tree_l, tree_r);
  if (mid >= right) {
    return determine_val(seg_tree, left_child(tree_idx), left, right, tree_l, mid);
  } else if (mid + 1 <= left) {
    return determine_val(seg_tree, right_child(tree_idx), left, right, mid + 1, tree_r);
  } else {
    return rb_funcall(seg_tree->combine_lambda, id_call, 2,
                       determine_val(seg_tree, left_child(tree_idx), left, mid, tree_l, mid),
                       determine_val(seg_tree, right_child(tree_idx), mid + 1, right, mid + 1, tree_r));
  }
}

static void update_val_at(segment_tree_data *seg_tree, size_t idx, size_t tree_idx, size_t tree_l, size_t tree_r) {
  if (tree_l == tree_r) {
    if (tree_l != idx) {
      rb_raise(eSharedInternalLogicError,
               "tree_l == tree_r == %lu but they do not agree with the idx %lu holding the updated value",
               (unsigned long)tree_r, (unsigned long)idx);
    }
    seg_tree->tree[tree_idx] = single_cell_val_at(seg_tree, tree_l);
  } else {
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);
    if (mid >= idx) {
      update_val_at(seg_tree, idx, left, tree_l, mid);
    } else {
      update_val_at(seg_tree, idx, right, mid + 1, tree_r);
    }
    seg_tree->tree[tree_idx] = combined_val(seg_tree, seg_tree->tree[left], seg_tree->tree[right]);
  }
}

/************************************************************
 * Fixnum fast path (long long aggregates, Ruby Array backing store)
 */

static void build_fixnum(segment_tree_data *st, size_t tree_idx, size_t tree_l, size_t tree_r) {
  if (tree_l == tree_r) {
    VALUE v = rb_ary_entry(st->data_array, (long)tree_l);
    st->tree_ll[tree_idx] = fixnum_leaf_ll(v);
    return;
  }

  size_t mid = midpoint(tree_l, tree_r);
  size_t left = left_child(tree_idx);
  size_t right = right_child(tree_idx);

  build_fixnum(st, left, tree_l, mid);
  build_fixnum(st, right, mid + 1, tree_r);

  st->tree_ll[tree_idx] = combine_ll(st->mode, st->tree_ll[left], st->tree_ll[right]);
}

static long long determine_val_ll(segment_tree_data *st, size_t tree_idx, size_t left, size_t right, size_t tree_l,
                                  size_t tree_r) {
  if (left == tree_l && right == tree_r) {
    return st->tree_ll[tree_idx];
  }

  size_t mid = midpoint(tree_l, tree_r);
  if (mid >= right) {
    return determine_val_ll(st, left_child(tree_idx), left, right, tree_l, mid);
  } else if (mid + 1 <= left) {
    return determine_val_ll(st, right_child(tree_idx), left, right, mid + 1, tree_r);
  } else {
    long long a = determine_val_ll(st, left_child(tree_idx), left, mid, tree_l, mid);
    long long b = determine_val_ll(st, right_child(tree_idx), mid + 1, right, mid + 1, tree_r);
    return combine_ll(st->mode, a, b);
  }
}

static void update_val_at_ll(segment_tree_data *st, size_t idx, size_t tree_idx, size_t tree_l, size_t tree_r) {
  if (tree_l == tree_r) {
    if (tree_l != idx) {
      rb_raise(eSharedInternalLogicError,
               "tree_l == tree_r == %lu but they do not agree with the idx %lu holding the updated value",
               (unsigned long)tree_r, (unsigned long)idx);
    }
    VALUE v = rb_ary_entry(st->data_array, (long)tree_l);
    st->tree_ll[tree_idx] = fixnum_leaf_ll(v);
  } else {
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);
    if (mid >= idx) {
      update_val_at_ll(st, idx, left, tree_l, mid);
    } else {
      update_val_at_ll(st, idx, right, mid + 1, tree_r);
    }
    st->tree_ll[tree_idx] = combine_ll(st->mode, st->tree_ll[left], st->tree_ll[right]);
  }
}

static void setup_fixnum(segment_tree_data *st, VALUE data_array, VALUE size_val, VALUE op, VALUE identity) {
  Check_Type(data_array, T_ARRAY);

  st->mode = (st_mode_t)op_sym_to_mode(op);
  st->identity = identity;
  st->data_array = data_array;  // We keep a reference to this so we can react to mutations on an update_at() call
  st->combine_lambda = Qnil;
  st->single_cell_array_val_lambda = Qnil;

  size_t n = checked_nonneg_fixnum(size_val);
  if (n == 0) {
    rb_raise(rb_eArgError, "size must be positive.");
  }
  if ((size_t)RARRAY_LEN(data_array) != n) {
    rb_raise(rb_eArgError, "data array length (%ld) must match size (%lu)", RARRAY_LEN(data_array), (unsigned long)n);
  }

  for (size_t i = 0; i < n; i++) {
    VALUE v = rb_ary_entry(data_array, (long)i);
    if (!RB_FIXNUM_P(v)) {
      rb_raise(rb_eTypeError,
               "fixnum fast path requires every element to be a Fixnum (index %lu is %+" PRIsVALUE ")", (unsigned long)i,
               v);
    }
  }

  st->size = n;

  xfree(st->tree);
  xfree(st->tree_ll);
  st->tree = NULL;

  size_t tree_size = 1 + 4 * st->size;
  st->tree_ll = calloc(tree_size, sizeof(long long));
  if (!st->tree_ll) {
    rb_raise(rb_eNoMemError, "calloc failed for fixnum segment tree");
  }
  st->tree_alloc_size = tree_size;

  build_fixnum(st, TREE_ROOT, 0, st->size - 1);
}

/************************************************************
 * Ruby method bindings
 */

static VALUE segment_tree_init(VALUE self, VALUE combine, VALUE single_cell_array_val, VALUE size, VALUE identity) {
  setup(unwrapped(self), combine, single_cell_array_val, size, identity);
  return self;
}

static VALUE segment_tree_init_fixnum(VALUE self, VALUE data_array, VALUE size_val, VALUE op, VALUE identity) {
  setup_fixnum(unwrapped(self), data_array, size_val, op, identity);
  return self;
}

static VALUE segment_tree_query_on(VALUE self, VALUE left, VALUE right) {
  segment_tree_data *seg_tree = unwrapped(self);
  size_t c_left = checked_nonneg_fixnum(left);
  size_t c_right = checked_nonneg_fixnum(right);

  if (c_right >= seg_tree->size) {
    rb_raise(eSharedDataError, "Bad query interval %lu..%lu (size = %lu)", (unsigned long)c_left, (unsigned long)c_right,
             (unsigned long)seg_tree->size);
  }

  if (c_left > c_right) {
    return seg_tree->identity;
  }

  if (seg_tree->mode == ST_MODE_GENERIC) {
    return determine_val(seg_tree, TREE_ROOT, c_left, c_right, 0, seg_tree->size - 1);
  }

  {
    long long ans = determine_val_ll(seg_tree, TREE_ROOT, c_left, c_right, 0, seg_tree->size - 1);
    return ll_to_ruby_num(ans);
  }
}

static VALUE segment_tree_update_at(VALUE self, VALUE idx) {
  segment_tree_data *seg_tree = unwrapped(self);
  size_t c_idx = checked_nonneg_fixnum(idx);

  if (c_idx >= seg_tree->size) {
    rb_raise(eSharedDataError, "Cannot update value at index %lu, size = %lu", (unsigned long)c_idx,
             (unsigned long)seg_tree->size);
  }

  if (seg_tree->mode == ST_MODE_GENERIC) {
    update_val_at(seg_tree, c_idx, TREE_ROOT, 0, seg_tree->size - 1);
  } else {
    update_val_at_ll(seg_tree, c_idx, TREE_ROOT, 0, seg_tree->size - 1);
  }

  return Qnil;
}

/*
 * CSegmentTreeTemplate.all_fixnums_for_fast_path?(array) -> true/false
 */
static VALUE segment_tree_s_all_fixnums_for_fast_path_p(VALUE klass, VALUE ary) {
  (void)klass;
  Check_Type(ary, T_ARRAY);
  long n = RARRAY_LEN(ary);
  for (long i = 0; i < n; i++) {
    if (!RB_FIXNUM_P(rb_ary_entry(ary, i))) {
      return Qfalse;
    }
  }
  return Qtrue;
}

void Init_c_segment_tree_template(void) {
  id_call = rb_intern("call");

  VALUE mSegmentTree = rb_define_module_under(mDataStructuresRMolinari, "SegmentTree");
  VALUE cSegmentTreeTemplate = rb_define_class_under(mSegmentTree, "CSegmentTreeTemplate", rb_cObject);

  rb_define_alloc_func(cSegmentTreeTemplate, segment_tree_alloc);
  rb_define_method(cSegmentTreeTemplate, "c_initialize", segment_tree_init, 4);
  rb_define_method(cSegmentTreeTemplate, "c_initialize_fixnum", segment_tree_init_fixnum, 4);
  rb_define_method(cSegmentTreeTemplate, "query_on", segment_tree_query_on, 2);
  rb_define_method(cSegmentTreeTemplate, "update_at", segment_tree_update_at, 1);
  rb_define_singleton_method(cSegmentTreeTemplate, "all_fixnums_for_fast_path?", segment_tree_s_all_fixnums_for_fast_path_p,
                             1);
}
