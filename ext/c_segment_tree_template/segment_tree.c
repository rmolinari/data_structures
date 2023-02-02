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

#ifdef DEBUG
#define debug(...) printf(__VA_ARGS__)
#else
#define debug(...)
#endif

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
  debug("Entering segment_tree_free\n");
  if (ptr) {
    segment_tree_data *segment_tree = ptr;
    debug("About to free segment tree at %p\n", segment_tree);
    debug("...about to cleanup vector at %p\n", segment_tree->tree);
    cleanup(segment_tree->tree);
    debug("...done with cleanup\n");
    xfree(segment_tree);
    debug("...done with xfree\n");
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
  debug("Entering segment_tree_mark\n");

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
 *
 * Note that we define the initializer on the Ruby side, at least for now.
 */
static VALUE segment_tree_alloc(VALUE klass) {
  // Get one on the heap
  segment_tree_data *segment_tree = create_segment_tree();
  // Wrap it up into a Ruby object
  return TypedData_Wrap_Struct(klass, &segment_tree_type, segment_tree);
}

// The (private) method that builds the internal structure
// TODO: pass the instance variable lambdas rather than accessing them from self each time.
void build(segment_tree_data *segment_tree, size_t tree_idx, size_t tree_l, size_t tree_r) {
  debug("build(_, %lu, %lu, %lu)\n", tree_idx, tree_l, tree_r);

  value_vector *tree = segment_tree->tree;

  if (tree_l == tree_r) {
    debug("About call @single_cell_array_val.call(%lu) %lu\n", tree_l, segment_tree->single_cell_array_val_lambda);
    lval(segment_tree->tree, tree_idx) = rb_funcall(segment_tree->single_cell_array_val_lambda, rb_intern("call"), 1, LONG2FIX(tree_l));
    debug("...done with the call\n");
  } else {
    size_t mid = midpoint(tree_l, tree_r);
    size_t left = left_child(tree_idx);
    size_t right = right_child(tree_idx);

    build(segment_tree, left, tree_l, mid);
    build(segment_tree, right, mid + 1, tree_r);

    debug("About to call @combine(%lu, %lu) @ %lu\n", left, right, segment_tree->combine_lambda);
    if (NIL_P(segment_tree->combine_lambda)) {
      //debug("But it is nil!!\n");
    }
    VALUE comb_val = rb_funcall(
                                  segment_tree->combine_lambda, rb_intern("call"), 2,
                                  *get(tree, left),
                                  *get(tree, right)
                                  );
    debug("The combined value is %lu of type %d\n", comb_val, TYPE(comb_val));
    lval(segment_tree->tree, tree_idx) = comb_val;
  }
}


/**
 * And now the simple wrappers around the C functionality. In each case we
 *   - unwrap a 'VALUE self',
 *     - i.e., the CSegmentTreeTemplate instance on the Ruby side;
 *   - munge any other arguments as needed
 *   - call the appropriate C function to act on the struct; and
 *   - return an appropriate VALUE for the Ruby runtime can use.
 *
 * We make them into methods on CSegmentTreeTemplate in the Init_c_segment_tree function, below.
 */

VALUE segment_tree_setup(VALUE self) {
  segment_tree_data *segment_tree = unwrapped(self);

  segment_tree->combine_lambda = combine(self);
  segment_tree->single_cell_array_val_lambda = single_cell_array_val(self);
  segment_tree->size = checked_nonneg_fixnum(seg_tree_size(self));

  debug("Size is %lu\n", segment_tree->size);

  debug("About to resize vector\n");
  resize(segment_tree->tree, 1 + 4 * segment_tree->size); // implicit binary tree with n leaves may use indices up to 4n.
  debug("done with resize vector. Size is now %lu\n", size(segment_tree->tree));

  build(segment_tree, TREE_ROOT, 0, segment_tree->size - 1);
  debug("done with build()\n");

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
  rb_define_private_method(cSegmentTreeTemplate, "setup", segment_tree_setup, 0);
  /* rb_define_method(cSegmentTreeTemplate, "make_set", segment_tree_make_set, 1); */
  /* rb_define_method(cSegmentTreeTemplate, "subset_count", segment_tree_subset_count, 0); */
  /* rb_define_method(cSegmentTreeTemplate, "find", segment_tree_find, 1); */
  /* rb_define_method(cSegmentTreeTemplate, "unite", segment_tree_unite, 2); */
}
