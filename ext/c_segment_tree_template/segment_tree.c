/*
 * This is a C implementation of a Segment Tree data structure.
 *
 * More specifically, it is the C version of the SegmentTreeTemplate Ruby class, for which see elsewhere in the repo.
 *
 * TODO: documentation
 */

#include "ruby.h"
#include "../cc.h" // Convenient Containers

// The Shared::DataError exception type in the Ruby code.
#define mShared rb_define_module("Shared")
#define eSharedDataError rb_const_get(mShared, rb_intern_const("DataError"))

// The instance variables
#define instance_var(obj, name)    rb_ivar_get(obj, rb_intern("@" #name))
#define single_cell_array_val(obj) instance_var(obj, single_cell_array_val)
#define combine(obj)               instance_var(obj, combine)
#define seg_tree_size(obj)         instance_var(obj, size)

//#define debug(...) printf(__VA_ARGS__)
#define debug(...)

/* The vector generic from Convenient Containers */
typedef vec(VALUE) value_vector;

/* What we might think of as vector[index]. It is assignable. */
#define lval(vector, index) (*get(vector, index))

/**
 * The C implementation of a generic Segment Tree
 */

/*
 * Binary tree arithmetic
 */
#define TREE_ROOT 1

static size_t midpoint(size_t left, size_t right) {
  return (left + right) / 2;
}

static size_t left_child(size_t i) {
  return i << 1;
}

static size_t right_child(size_t i) {
  return 1 + (i << 1);
}

typedef struct {
  value_vector *tree; // The 1-based synthetic binary tree in which the data structure lives
  VALUE single_cell_array_val_lambda;
  VALUE combine_lambda;
  VALUE identity;
  size_t size;
} segment_tree_data;

/*
 * Create one (on the heap).
 */
static segment_tree_data *create_segment_tree() {
  segment_tree_data *segment_tree = malloc(sizeof(segment_tree_data));

  // Allocate the structures
  segment_tree->tree = malloc(sizeof(value_vector));
  init(segment_tree->tree);

  // Index 0 of the vector isn't used. Our implied binary tree structure is 1-based. So stick NULL at index 0.
  push(segment_tree->tree, (VALUE)0);

  segment_tree->single_cell_array_val_lambda = 0;
  segment_tree->combine_lambda = 0;
  segment_tree->size = 0; // we don't know the right value yet

  return segment_tree;
}

/*
 * Free the memory associated with a segment_tree.
 *
 * This will end up getting triggered by the Ruby garbage collector. Ruby learns about it via the segment_tree_type struct below.
 */
static void segment_tree_free(void *ptr) {
  if (ptr) {
    segment_tree_data *segment_tree = ptr;
    cleanup(segment_tree->tree);
    xfree(segment_tree);
  }
}

/************************************************************
 * The Segment Tree operations in C
 ************************************************************/

/**
 * Wrapping and unwrapping things for the Ruby runtime
 *
 */

// How much memory (roughly) does a segment_tree_data instance consume? I guess the Ruby runtime can use this information when
// deciding how agressive to be during garbage collection and such.
static size_t segment_tree_memsize(const void *ptr) {
  if (ptr) {
    const segment_tree_data *st = ptr;

    // See https://github.com/JacksonAllan/CC/issues/3
    return sizeof( cc_vec_hdr_ty ) + cap( st->tree ) * CC_EL_SIZE( *(st->tree) );
  } else {
    return 0;
  }
}

// We need to mark any ruby objects we are holding, to stop the Ruby runtime from garbage collecting them.
static void segment_tree_mark(void *ptr) {
  segment_tree_data *st = ptr;

  rb_gc_mark(st->combine_lambda);
  rb_gc_mark(st->single_cell_array_val_lambda);

  for_each( st->tree, value ) {
    if (value) {
      rb_gc_mark(*value);
    }
  }
}

/*
 * A configuration struct that tells the Ruby runtime how to deal with a segment_tree_data object.
 *
 * https://docs.ruby-lang.org/en/master/extension_rdoc.html#label-Encapsulate+C+data+into+a+Ruby+object
 */
static const rb_data_type_t segment_tree_type = {
  .wrap_struct_name = "segment_tree_template",
  { // help for the Ruby garbage collector
    .dmark = segment_tree_mark, // dmark, for marking other Ruby objects.
    .dfree = segment_tree_free, // how to free the memory associated with an object
    .dsize = segment_tree_memsize, // roughly how much space does the object consume?
  },
  .data = NULL, // a data field we could use for something here if we wanted. Ruby ignores it
  .flags = 0  // GC-related flag values.
};

/*
 * Helper: check that a Ruby value is a non-negative Fixnum and convert it to a C unsigned long
 */
static unsigned long checked_nonneg_fixnum(VALUE val) {
  Check_Type(val, T_FIXNUM);
  long c_val = FIX2LONG(val);

  if (c_val < 0) {
    rb_raise(eSharedDataError, "Value must be non-negative");
  }

  return c_val;
}

/*
 * Unwrap a Ruby-side disjoint union object to get the C struct inside.
 */
static segment_tree_data *unwrapped(VALUE self) {
  segment_tree_data *segment_tree;
  TypedData_Get_Struct((self), segment_tree_data, &segment_tree_type, segment_tree);
  return segment_tree;
}

/*
 * This is for CSegmentTreeTemplate.allocate on the Ruby side.
 */
static VALUE segment_tree_alloc(VALUE klass) {
  // Get one on the heap
  segment_tree_data *segment_tree = create_segment_tree();
  // Wrap it up into a Ruby object
  return TypedData_Wrap_Struct(klass, &segment_tree_type, segment_tree);
}


// Build the internal data structure.
static void build(segment_tree_data *segment_tree, size_t tree_idx, size_t tree_l, size_t tree_r) {
  value_vector *tree = segment_tree->tree;

  if (tree_l == tree_r) {
    lval(segment_tree->tree, tree_idx) = rb_funcall(segment_tree->single_cell_array_val_lambda, rb_intern("call"), 1, LONG2FIX(tree_l));
  } else {
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);

    build(segment_tree, left, tree_l, mid);
    build(segment_tree, right, mid + 1, tree_r);

    VALUE comb_val = rb_funcall(
                                  segment_tree->combine_lambda, rb_intern("call"), 2,
                                  *get(tree, left),
                                  *get(tree, right)
                                  );
    lval(segment_tree->tree, tree_idx) = comb_val;
  }
}

static void setup(segment_tree_data* seg_tree, VALUE combine, VALUE single_cell_array_val, VALUE size, VALUE identity) {
  VALUE idCall = rb_intern("call");

  if (!rb_obj_respond_to(combine, idCall, TRUE)) {
    rb_raise(rb_eArgError, "wrong type argument %"PRIsVALUE" (should be callable)", rb_obj_class(combine));
  }

  if (!rb_obj_respond_to(single_cell_array_val, idCall, TRUE)) {
    rb_raise(rb_eArgError, "wrong type argument %"PRIsVALUE" (should be callable)", rb_obj_class(single_cell_array_val));
  }

  seg_tree->combine_lambda = combine;
  seg_tree->single_cell_array_val_lambda = single_cell_array_val;
  seg_tree->identity = identity;
  seg_tree->size = checked_nonneg_fixnum(size);

  if (seg_tree->size == 0) {
    rb_raise(rb_eArgError, "size must be positive.");
  }

  size_t vec_size = 1 + 4 * seg_tree->size; // implicit binary tree with n leaves may use indices up to 4n.
  resize(seg_tree->tree, vec_size);
  for (size_t i = 1; i < vec_size; i++) {
    lval(seg_tree->tree, i) = (VALUE)0;
  }

  build(seg_tree, TREE_ROOT, 0, seg_tree->size - 1);
}


static VALUE determine_val(segment_tree_data* seg_tree, size_t tree_idx, size_t left, size_t right, size_t tree_l, size_t tree_r) {
  // Does the current tree node exactly serve up the interval we're interested in?
  if (left == tree_l && right == tree_r) {
    return lval(seg_tree->tree, tree_idx);
  }

  // We need to go further down the tree */
  size_t mid = midpoint(tree_l, tree_r);
  if (mid >= right) {
    // Our interval is contained by the left child's interval
    return determine_val(seg_tree, left_child(tree_idx),  left, right, tree_l,  mid);
  } else if (mid + 1 <= left) {
    // Our interval is contained by the right child's interval
    return determine_val(seg_tree, right_child(tree_idx), left, right, mid + 1, tree_r);
  } else {
    // Our interval is split between the two, so we need to combine the results from the children.
    return rb_funcall(
                      seg_tree->combine_lambda, rb_intern("call"), 2,
                      determine_val(seg_tree, left_child(tree_idx),  left,    mid,   tree_l,  mid),
                      determine_val(seg_tree, right_child(tree_idx), mid + 1, right, mid + 1, tree_r)
                      );
  }
}

/**
 * And now the wrappers around the C functionality.
 */

// #initialize
static VALUE segment_tree_init(VALUE self, VALUE combine, VALUE single_cell_array_val, VALUE size, VALUE identity) {
  setup(unwrapped(self), combine, single_cell_array_val, size, identity);
  return self;
}

// #query_on
static VALUE segment_tree_query_on(VALUE self, VALUE left, VALUE right) {
  segment_tree_data* seg_tree = unwrapped(self);
  size_t c_left = checked_nonneg_fixnum(left);
  size_t c_right = checked_nonneg_fixnum(right);

  if (c_right >= seg_tree->size) {
    rb_raise(eSharedDataError, "Bad query interval %lu..%lu (size = %lu)", c_left, c_right, seg_tree->size);
  }

  if (left > right) {
    // empty interval.
    return seg_tree->identity;
  }

  return determine_val(seg_tree, TREE_ROOT, c_left, c_right, 0, seg_tree->size - 1);
}


/*
 * A generic Segment Tree
 *
 * TODO: write documentation
 */
void Init_c_segment_tree_template() {
  VALUE mDataStructuresRMolinari = rb_define_module("DataStructuresRMolinari");
  VALUE cSegmentTreeTemplate = rb_define_class_under(mDataStructuresRMolinari, "CSegmentTreeTemplate", rb_cObject);

  rb_define_alloc_func(cSegmentTreeTemplate, segment_tree_alloc);
  rb_define_method(cSegmentTreeTemplate, "c_initialize", segment_tree_init, 4);
  rb_define_method(cSegmentTreeTemplate, "query_on", segment_tree_query_on, 2);
}
