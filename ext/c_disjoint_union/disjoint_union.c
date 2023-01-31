/*
 * This is a C implementation of a simple Ruby Disjoint Union data structure.
 *
 * A Disjoint Union doesn't have much of an implementation in Ruby: see disjoint_union.rb in this gem. This means that we don't gain
 * much by implementing it in C but that it serves as a good learning experience for me.
 *
 * It turns out that writing a C extension for Ruby like this isn't very complicated, but there are a bunch of moving parts and the
 * available documentation is a bit of a slog. Writing this was very educational.
 *
 * See https://docs.ruby-lang.org/en/master/extension_rdoc.html for some documentation. It's a bit hard to read in places, but
 * plugging away at things helps.
 *
 * https://guides.rubygems.org/gems-with-extensions/ is a decent tutorial, though it leaves out lots of details.
 *
 * See https://aaronbedra.com/extending-ruby/ for another tutorial.
 */

#include "ruby.h"
#include "../dynamic_array.h"

// Try storing the rank and forest information together for data locality.
typedef struct data_pair {
  long parent;
  unsigned long rank;
} data_pair;

static data_pair make_data_pair(long parent, unsigned long rank) {
  data_pair pair = { .parent = parent, .rank = rank };
  return pair;
}

#define DEFAULT_PARENT -1
#define DEFAULT_RANK 0
static data_pair default_pair = {
  .parent = DEFAULT_PARENT,
  .rank = DEFAULT_RANK
};

DEFINE_VEC_WITH_INIT(data_pair);
typedef VecArray_data_pair VecArray;

#define parent(disjoint_union_ptr, idx) (get(disjoint_union->pairs->vector, idx)->parent)
#define rank(disjoint_union_ptr, idx) (get(disjoint_union->pairs->vector, idx)->rank)

#define set_parent(disjoint_union_ptr, idx, val) (get(disjoint_union->pairs->vector, idx)->parent = val)
#define set_rank(disjoint_union_ptr, idx, val) (get(disjoint_union->pairs->vector, idx)->rank = val)

// TODO: eliminate the need for this. Unfortunately the _Generic macros in dynamic_array.h need to see all the types in the _Generic
// list. Convenient Contains has a way of avoiding this, but not sure if we can use it ourselves.
DEFINE_VEC_WITH_INIT(long);
/* typedef VecArray_long VecArray; */

// The Shared::DataError exception type in the Ruby code. We only need it when we detect a runtime error, so a macro should be fine.
#define mShared rb_define_module("Shared")
#define eSharedDataError rb_const_get(mShared, rb_intern_const("DataError"))

/**
 * The C implementation of a Disjoint Union
 *
 * See Tarjan, Robert E., van Leeuwen, J., _Worst-case Analysis of Set Union Algorithms_, Journal of the ACM, v31:2 (1984), pp 245–281.
 */

/*
 * The Disjoint Union struct.
 * - forest: an array of longs giving, for each element, the element's parent.
 *   - An element e is the root of its tree just when forest[e] == e.
 *   - Two elements are in the same subset just when they are in the same tree in the forest.
 *     - So the key idea is that we can check this by navigating via parents from each element to their roots. Clever optimizations
 *       keep the trees flat and so most nodes are close to their roots.
 * - rank: a array of longs giving the "rank" of each element.
 *   - This value is used to guide the "linking" of trees when subsets are being merged to keep the trees flat. See Tarjan & van
 *     Leeuwen
 * - subset_count: the number of (disjoint) subsets.
 *   - it isn't needed internally but may be useful to client code.
 */
typedef struct du_data {
  VecArray *pairs;
  size_t subset_count;
} disjoint_union_data;

/*
 * Create one (on the heap).
 */
#define INITIAL_SIZE 100
static disjoint_union_data *create_disjoint_union() {
  disjoint_union_data *disjoint_union = (disjoint_union_data *)malloc(sizeof(disjoint_union_data));

  // Allocate the structures
  VecArray *pairs = (VecArray *)malloc(sizeof(VecArray));
  init_vec(pairs, default_pair);

  disjoint_union->pairs = pairs;
  disjoint_union->subset_count = 0;

  return disjoint_union;
}

/*
 * Free the memory associated with a disjoint union.
 *
 * This will end up getting triggered by the Ruby garbage collector. Ruby learns about it via the disjoint_union_type struct below.
 */
static void disjoint_union_free(void *ptr) {
  if (ptr) {
    disjoint_union_data *disjoint_union = ptr;
    free_vec(disjoint_union->pairs);

    free(disjoint_union->pairs);
    disjoint_union->pairs = NULL;

    xfree(disjoint_union);
  }
}

/************************************************************
 * The disjoint union operations
 ************************************************************/

/*
 * Is the given element already a member of the universe?
 */
static int present_p(disjoint_union_data *disjoint_union, size_t element) {
  // VecArray *forest = (VecArray *)disjoint_union->forest;
  // printf("present_p: forest size = %zu", size(forest->vector));
  return (size(disjoint_union->pairs->vector) > element && (parent(disjoint_union, element) != DEFAULT_PARENT));
}

/*
 * Check that the given element is a member of the universe and raise Shared::DataError (ruby-side) if not
 */
static void assert_membership(disjoint_union_data *disjoint_union, size_t element) {
  if (!present_p(disjoint_union, element)) {
    // rb_raise(eSharedDataError, "Value %zu is not part of the universe", element);
    rb_raise(
             eSharedDataError,
             "Value %zu is not part of the universe, size = %zu, forest_val = %lu",
             element,
             size(disjoint_union->pairs->vector),
             get(disjoint_union->pairs->vector, element)->parent
             );
  }
}

/*
 * Add a new element to the universe. It starts out in its own singleton subset.
 *
 * Shared::DataError is raised if it is already an element.
 */
static void add_new_element(disjoint_union_data *disjoint_union, size_t element) {
  if (present_p(disjoint_union, element)) {
    rb_raise(eSharedDataError, "Element %zu already present in the universe", element);
  }

  set_vec_elt(disjoint_union->pairs, element, make_data_pair((long)element, 0l) );
  disjoint_union->subset_count++;
}

/*
 * Find the canonical representative of the given element. This is the root of the tree (in forest) containing element.
 *
 * Two elements are in the same subset exactly when their canonical representatives are equal.
 */
static size_t find(disjoint_union_data *disjoint_union, size_t element) {
  assert_membership(disjoint_union, element);

  // We implement find with "halving" to shrink the length of paths to the root. See Tarjan and van Leeuwin p 252.
  // vec(long) *d = disjoint_union->forest->vector; // the actual forest data
  size_t x = element;
  while (parent(disjoint_union, parent(disjoint_union, x)) != parent(disjoint_union, x)) {
    long v = parent(disjoint_union, parent(disjoint_union, x));
    set_parent(disjoint_union, x, v);
    x = v;
  }
  return parent(disjoint_union, x);
}

/*
 * "Link"" the two given elements so that they are in the same subset now.
 *
 * In other words, merge the subtrees containing the two elements.
 *
 * Good performace (see Tarjan and van Leeuwin) assumes that elt1 and elt2 area are disinct and already the roots of their trees,
 * though we don't check that here.
 */
static void link_roots(disjoint_union_data *disjoint_union, size_t elt1, size_t elt2) {
  /* vec(long) *rank = disjoint_union->rank->vector; */
  /* vec(long) *forest = disjoint_union->forest->vector; */

  if (rank(disjoint_union, elt1) > rank(disjoint_union, elt2)) {
    set_parent(disjoint_union, elt2, elt1);
  } else if (rank(disjoint_union, elt1) == rank(disjoint_union, elt2)) {
    set_parent(disjoint_union, elt2, elt1);
    rank(disjoint_union, elt1)++;
  } else {
    set_parent(disjoint_union, elt1, elt2);
  }

  disjoint_union->subset_count--;
}

/*
 * "Unite" or merge the subsets containing elt1 and elt2.
 */
static void unite(disjoint_union_data *disjoint_union, size_t elt1, size_t elt2) {
  assert_membership(disjoint_union, elt1);
  assert_membership(disjoint_union, elt2);

  if (elt1 == elt2) {
    rb_raise(eSharedDataError, "Uniting an element with itself is meaningless");
  }

  size_t root1 = find(disjoint_union, elt1);
  size_t root2 = find(disjoint_union, elt2);

  if (root1 == root2) {
    return; // already united
  }

  link_roots(disjoint_union, root1, root2);
}


/**
 * Wrapping and unwrapping things for the Ruby runtime
 *
 */

// How much memory (roughly) does a disjoint_union_data instance consume? I guess the Ruby runtime can use this information when
// deciding how agressive to be during garbage collection and such.
//
// TODO: work out what to do with the underlying CC vec
static size_t disjoint_union_memsize(const void *ptr) {
  return 0;
  /* if (ptr) { */
  /*   const disjoint_union_data *du = ptr; */
  /*   return sizeof(disjoint_union_data) + _size_of(du->forest) + _size_of(du->rank); */
  /* } else { */
  /*   return 0; */
  /* } */
}

/*
 * A configuration struct that tells the Ruby runtime how to deal with a disjoint_union_data object.
 *
 * https://docs.ruby-lang.org/en/master/extension_rdoc.html#label-Encapsulate+C+data+into+a+Ruby+object
 */
static const rb_data_type_t disjoint_union_type = {
  .wrap_struct_name = "disjoint_union",
  { // help for the Ruby garbage collector
    .dmark = NULL, // dmark, for marking other Ruby objects. We don't hold any other objects so this can be NULL
    .dfree = disjoint_union_free, // how to free the memory associated with an object
    .dsize = disjoint_union_memsize, // roughly how much space does the object consume?
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
 * Unwrap a Rubyfied disjoint union to get the C struct inside.
 */
static disjoint_union_data *unwrapped(VALUE self) {
  disjoint_union_data *disjoint_union;
  TypedData_Get_Struct((self), disjoint_union_data, &disjoint_union_type, disjoint_union);
  return disjoint_union;
}

/*
 * This is for CDisjointUnion.allocate on the Ruby side
 */
static VALUE disjoint_union_alloc(VALUE klass) {
  // Get one on the heap
  disjoint_union_data *disjoint_union = create_disjoint_union();
  // Wrap it up into a Ruby object
  return TypedData_Wrap_Struct(klass, &disjoint_union_type, disjoint_union);
}

/*
 * A single parameter is optional. If given it should be a non-negative integer and specifies the initial size, s, of the universe
 * 0, 1, ..., s-1.
 *
 * If no argument is given we act as though a value of 0 were passed.
 */
static VALUE disjoint_union_init(int argc, VALUE *argv, VALUE self) {
  if (argc == 0) {
    return self;
  } else if (argc > 1) {
    rb_raise(rb_eArgError, "wrong number of arguments");
  } else {
    size_t initial_size = checked_nonneg_fixnum(argv[0]);
    disjoint_union_data *disjoint_union = unwrapped(self);

    vec(data_pair) *pair_vec = disjoint_union->pairs->vector;
    resize(pair_vec, initial_size);

    for (size_t i = 0; i < initial_size; i++) {
      vec_set(pair_vec, i, make_data_pair(i, 0));
    }
    disjoint_union->subset_count = initial_size;
  }
  return self;
}

/**
 * And now the simple wrappers around the Disjoint Union C functionality. In each case we
 *   - unwrap a 'VALUE self',
 *     - i.e., theCDisjointUnion instance that contains a disjoint_union_data struct;
 *   - munge any other arguments into longs;
 *   - call the appropriate C function to act on the struct; and
 *   - return an appropriate VALUE for the Ruby runtime can use.
 *
 * We make them into methods on CDisjointUnion in the Init_CDisjointUnion function, below.
 */

/*
 * Add a new subset to the universe containing the element +new_v+.
 *
 * @param the new element, starting in its own singleton subset
 *   - it must be a non-negative integer, not already part of the universe of elements.
 */
static VALUE disjoint_union_make_set(VALUE self, VALUE arg) {
  add_new_element(unwrapped(self), checked_nonneg_fixnum(arg));

  return Qnil;
}

/*
 * @return the number of subsets into which the universe is currently partitioned.
 */
static VALUE disjoint_union_subset_count(VALUE self) {
  return LONG2NUM(unwrapped(self)->subset_count);
}

/*
 * The canonical representative of the subset containing e. Two elements d and e are in the same subset exactly when find(d) ==
 * find(e).
 *
 * The parameter must be in the universe of elements.
 *
 * @return (Integer) one of the universe of elements
 */
static VALUE disjoint_union_find(VALUE self, VALUE arg) {
  return LONG2NUM(find(unwrapped(self), checked_nonneg_fixnum(arg)));
}

/*
 * Declare that the arguments are equivalent, i.e., in the same subset. If they are already in the same subset this is a no-op.
 *
 * Each argument must be in the universe of elements
 */
static VALUE disjoint_union_unite(VALUE self, VALUE arg1, VALUE arg2) {
  unite(unwrapped(self), checked_nonneg_fixnum(arg1), checked_nonneg_fixnum(arg2));

  return Qnil;
}

/*
 * A Disjoint Union.
 *
 * A "disjoint set union" that represents a set of elements that belonging to _disjoint_ subsets. Alternatively, this expresses a
 * partion of a fixed set.
 *
 * The data structure provides efficient actions to merge two disjoint subsets, i.e., replace them by their union, and determine if
 * two elements are in the same subset.
 *
 * The elements of the set are non-negative integers. Client code can map its data to these representatives.
 *
 * See https://en.wikipedia.org/wiki/Disjoint-set_data_structure for a good introduction.
 *
 * The code uses several ideas from Tarjan and van Leeuwen for efficiency. We use "union by rank" in +unite+ and path-halving in
 * +find+. Together, these make the amortized cost of each opperation effectively constant.
 *
 * - Tarjan, Robert E., van Leeuwen, Jan (1984). _Worst-case analysis of set union algorithms_. Journal of the ACM. 31 (2): 245–281.
 */
void Init_c_disjoint_union() {
  VALUE mDataStructuresRMolinari = rb_define_module("DataStructuresRMolinari");
  VALUE cDisjointUnion = rb_define_class_under(mDataStructuresRMolinari, "CDisjointUnion", rb_cObject);

  rb_define_alloc_func(cDisjointUnion, disjoint_union_alloc);
  rb_define_method(cDisjointUnion, "initialize", disjoint_union_init, -1);
  rb_define_method(cDisjointUnion, "make_set", disjoint_union_make_set, 1);
  rb_define_method(cDisjointUnion, "subset_count", disjoint_union_subset_count, 0);
  rb_define_method(cDisjointUnion, "find", disjoint_union_find, 1);
  rb_define_method(cDisjointUnion, "unite", disjoint_union_unite, 2);
}
