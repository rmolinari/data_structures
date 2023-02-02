/*
 * This is a C implementation of a Segment Tree data structure.
 *
 * More specifically, it is the C version of the SegmentTreeTemplate Ruby class, for which see elsewhere in the repo.
 *
 * TODO:
 * - documentation
 * - reorganize the code
 * - update() support
 * - move some things into a shared .h
 */

#include "ruby.h"
#include "../cc.h" // Convenient Containers

// Shared::FooError exception types
// TODO: into shared header
#define mShared rb_define_module("Shared")
#define eSharedDataError rb_const_get(mShared, rb_intern_const("DataError"))
#define eSharedInternalLogicError rb_const_get(mShared, rb_intern_const("InternalLogicError"))

// TODO: into shared header
//#define debug(...) printf(__VA_ARGS__)
#define debug(...)

/* The vector generic from Convenient Containers */
typedef vec(VALUE) value_vector;

/* What we might think of as vector[index]. It is assignable. TODO: into shared header */
#define lval(vector, index) (*get(vector, index))
#define single_cell_val_at(seg_tree, idx) rb_funcall(seg_tree->single_cell_array_val_lambda, rb_intern("call"), 1, LONG2FIX(idx))
#define combined_val(seg_tree, v1, v2) rb_funcall(seg_tree->combine_lambda, rb_intern("call"), 2, (v1), (v2))
/**
 * The C implementation of a generic Segment Tree
 */

/*
 * Binary tree arithmetic for an implicit tree in an array, 1-based.
 *
 * TODO: into shared header
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

// TODO: use a VALUE* instead of a vec(VALUE) for tree. We know the size when we allocate it in setup().
typedef struct {
  value_vector *tree; // The 1-based implicit binary tree in which the data structure lives
  VALUE single_cell_array_val_lambda;
  VALUE combine_lambda;
  VALUE identity;
  size_t size;
} segment_tree_data;

/************************************************************
 * Memory Management
 *
 */

/*
 * Create one (on the heap).
 */
static segment_tree_data *create_segment_tree() {
  segment_tree_data *segment_tree = malloc(sizeof(segment_tree_data));

  // Allocate the structures
  segment_tree->tree = malloc(sizeof(value_vector));
  init(segment_tree->tree);

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

/*
 * How much memory (roughly) does a segment_tree_data instance consume?
 *
 * I guess the Ruby runtime can use this information when deciding how agressive to be during garbage collection and such.
 */
static size_t segment_tree_memsize(const void *ptr) {
  if (ptr) {
    const segment_tree_data *st = ptr;

    // See https://github.com/JacksonAllan/CC/issues/3
    return
      sizeof( cc_vec_hdr_ty )
      + cap( st->tree ) * CC_EL_SIZE( *(st->tree) )
      + sizeof(segment_tree_data);
  } else {
    return 0;
  }
}

/*
 * Mark the Ruby objects we hold so that the Ruby garbage collector knows that they are still in use.
 */
static void segment_tree_mark(void *ptr) {
  segment_tree_data *st = ptr;

  rb_gc_mark(st->combine_lambda);
  rb_gc_mark(st->single_cell_array_val_lambda);
  rb_gc_mark(st->identity);

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
 * End memory management functions.
 ************************************************************/


/************************************************************
 * Wrapping and unwrapping the C struct and other things.
 *
 */

/*
 * Unwrap a Ruby-side disjoint union object to get the C struct inside.
 *
 * TODO: consider a macro in a shared header
 */
static segment_tree_data *unwrapped(VALUE self) {
  segment_tree_data *segment_tree;
  TypedData_Get_Struct((self), segment_tree_data, &segment_tree_type, segment_tree);
  return segment_tree;
}

/*
 * Check that a Ruby value is a non-negative Fixnum and convert it to a C unsigned long
 *
 * TODO: into a shared header and .c
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
 * Allocate a segment_tree_data struct and wrap it for the Ruby runtime.
 *
 * This is for CSegmentTreeTemplate.allocate on the Ruby side.
 */
static VALUE segment_tree_alloc(VALUE klass) {
  // Get one on the heap
  segment_tree_data *segment_tree = create_segment_tree();
  // ...and wrap it into a Ruby object
  return TypedData_Wrap_Struct(klass, &segment_tree_type, segment_tree);
}

/*
 * End wrapping and unwrapping functions.
 ************************************************************/

/************************************************************
 * The Segment Tree API on the C side.
 *
 * We wrap these in the Ruby-ready functions below
 */

/*
 * Recursively build the internal tree data structure.
 *
 * - tree_idx: the index into the tree array of the node being calculated
 * - [tree_l, tree_r]: the sub-interval of the underlying array data corresponding to the tree node being calculated.
 */
static void build(segment_tree_data *segment_tree, size_t tree_idx, size_t tree_l, size_t tree_r) {
  value_vector *tree = segment_tree->tree;

  if (tree_l == tree_r) {
    // Base case: the node corresponds to a subarray of length 1.
    lval(segment_tree->tree, tree_idx) = single_cell_val_at(segment_tree, tree_l);
  } else {
    // Build to two child nodes, and then combine their values for this node.
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);

    build(segment_tree, left, tree_l, mid);
    build(segment_tree, right, mid + 1, tree_r);

    /* VALUE comb_val = rb_funcall( */
    /*                             segment_tree->combine_lambda, rb_intern("call"), 2, */
    /*                             *get(tree, left), // we just built these two values in the recursive calls. */
    /*                             *get(tree, right) */
    /*                             ); */
    VALUE comb_val = combined_val(segment_tree, *get(tree, left), *get(tree, right));
    lval(segment_tree->tree, tree_idx) = comb_val;
  }
}

/*
 * Set up the internals with the arguments we get from #initialize.
 *
 * - combine: must be callable
 * - single_cell_array_val: must be callable
 * - size: must be a positive integer
 * - identity: we don't care what it is.
 *   - maybe we should check at least that it is not 0. But Qnil is fine.
 */
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

  // Implicit binary tree with n leaves and straightforward left() and right() may use indices up to 4n.  But see here for a way to
  // reduce the requirement to 2n: https://cp-algorithms.com/data_structures/segment_tree.html#memory-efficient-implementation
  size_t vec_size = 1 + 4 * seg_tree->size;
  resize(seg_tree->tree, vec_size);
  for (size_t i = 0; i < vec_size; i++) {
    lval(seg_tree->tree, i) = (VALUE)0;
  }

  build(seg_tree, TREE_ROOT, 0, seg_tree->size - 1);
}


/*
 * Determine the value for the subarray A(left, right).
 *
 * - tree_idx: the index in the array of the node we are currently visiting
 * - tree_l..tree_r: the subarray handled by the current node.
 * - left..right: the subarray whose value we are currently looking for.
 *
 * As an invariant we have left..right \subset tree_l..tree_r.
 *
 * We start out with
 * - tree_idx = TREE_ROOT
 * - tree_l..tree_r = 0..(size - 1), and
 * - left..right given by the client code's query
 *
 * If [tree_l, tree_r] = [left, right] then the current node gives the desired answer. Otherwise we decend the tree with one or two
 * recursive calls.
 *
 * If left..right is contained the the bottom or top half of tree_l..tree_r we decend to the corresponding child with one recursive
 * call. Otherwise we split left..right at the midpoint of tree_l..tree_r, make two recursive calls, and then combine the results.
 */
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

/*
 * Update the structure to reflect the change in the underlying array at index idx.
 *
 * - idx: the index at which the underlying array data has changed.
 * - tree_id: the index in the internal datastructure of the node we are currently visiting.
 * - tree_l..tree_r: the range handled by the current node
 */
static void update_val_at(segment_tree_data *seg_tree, size_t idx, size_t tree_idx, size_t tree_l, size_t tree_r) {
  if (tree_l == tree_r) {
    // We have found the base case of our update
    if (tree_l != idx) {
      rb_raise(
               eSharedInternalLogicError,
               "tree_l == tree_r == %lu but they do not agree with the idx %lu holding the updated value",
               tree_r, idx
               );
    }
    lval(seg_tree->tree, tree_idx) = single_cell_val_at(seg_tree, tree_l);
  } else {
    // Recursively update the appropriate subtree...
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);
    if (mid >= idx) {
      update_val_at(seg_tree, idx, left, tree_l, mid);
    } else {
      update_val_at(seg_tree, idx, right, mid + 1, tree_r);
    }
    // ...and ourself to incorporate the change
    lval(seg_tree->tree, tree_idx) = combined_val(seg_tree, *get(seg_tree->tree, left), *get(seg_tree->tree, right));
  }
}

/**
 * And now the wrappers around the C functionality.
 */

/*
 * CSegmentTreeTemplate#c_initialize
 */
static VALUE segment_tree_init(VALUE self, VALUE combine, VALUE single_cell_array_val, VALUE size, VALUE identity) {
  setup(unwrapped(self), combine, single_cell_array_val, size, identity);
  return self;
}

/*
 * CSegmentTreeTemplate#query_on.
 */
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
 * CSegmentTreeTemplate#update_at
 */
static VALUE segment_tree_update_at(VALUE self, VALUE idx) {
  segment_tree_data *seg_tree = unwrapped(self);
  size_t c_idx = checked_nonneg_fixnum(idx);

  if (c_idx >= seg_tree->size) {
    rb_raise(eSharedDataError, "Cannot update value at index %lu, size = %lu", c_idx, seg_tree->size);
  }

  update_val_at(seg_tree, c_idx, TREE_ROOT, 0, seg_tree->size - 1);

  return Qnil;
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
  rb_define_method(cSegmentTreeTemplate, "update_at", segment_tree_update_at, 1);
}
