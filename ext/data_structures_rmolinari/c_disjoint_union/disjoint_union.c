#include "ruby.h"

static VALUE mDataStructuresRMolinari;
static VALUE cDisjointUnion;
static VALUE mShared;
static ID id_DataError;

#define eDataError rb_const_get(mShared, id_DataError)

/**
 * It's been so long since I've written non-trival C that I need to copy examples from online
 * Dynamic array of longs, with an initial value for otherwise uninitialized elements..

 * Based on  https://stackoverflow.com/questions/3536153/c-dynamically-growing-array
 */
#define DEFAULT_ARRAY_VAL -1L
typedef struct {
  long *array;
  size_t size;
  long default_val;
} Array;

void initArray(Array *a, size_t initial_size, long default_val) {
  a->array = malloc(initial_size * sizeof(long));
  a->size = initial_size;
  a->default_val = default_val;

  for (unsigned long i = 0; i < initial_size; i++) {
    a->array[i] = default_val;
  }
}

void insertArray(Array *a, unsigned long index, long element) {
  // printf("In insertArray for index %zu, size=%zu\n", index, a->size );
  if (a->size <= index) {
    size_t new_size = a->size;
    while (new_size <= index) {
      new_size = 8 * new_size / 5 + 8; // 8/5 gives "Fibonnacci-like" growth; adding 8 to avoid small arrays having to reallocate
                                       // too often
    }
    long* new_array = realloc(a->array, new_size * sizeof(long));
    if (!new_array) {
      rb_raise(rb_eRuntimeError, "Cannot allocate memory to expand Array!");
    }
    a->array = new_array;
    for (size_t i = a->size; i < new_size; i++) {
      // printf("Setting a->array[%zu] = %li", i, DEFAULT_ARRAY_VAL);
      a->array[i] = a->default_val;
    }

    a->size = new_size;
  }

  a->array[index] = element;
}

void freeArray(Array *a) {
  //printf("In freeArray of size %zu. About to free %p\n", a->size, (void *) a->array);
  free(a->array);
  a->array = NULL;
  a->size = 0;
}

/** END simple dynamic array
 ************************************************************/

/**
 * The Ruby Extension stuff.
 *
 * See https://docs.ruby-lang.org/en/master/extension_rdoc.html for lots of details (that need to be waded through).
 */

/*
 * This is the struct that "is" the Disjoint Union object from a Ruby perspective. As I understand it, "instance variables" live
 * here. We use TypedData_Wrap_Struct below to make it into an object as understood by the Ruby runtime.
 *
 * See https://docs.ruby-lang.org/en/master/extension_rdoc.html#label-Example+-+Creating+the+dbm+Extension for some example code.
 */
typedef struct du_data {
  Array* forest; // the forest that describes the unified subsets
  Array* rank;
  size_t subset_count;
} disjoint_union_data;

// Free a DisjointUnion struct for the Ruby GC
static void disjoint_union_free(void *ptr) {
  //printf("In disjoint_union_free for pointer %p\n", ptr);
  if (ptr) {
    disjoint_union_data *disjoint_union = ptr;
    //printf("   In disjoint_union_free...about to call freeArray\n");
    freeArray(disjoint_union->forest);
    freeArray(disjoint_union->rank);
    free(disjoint_union->forest);
    free(ptr);
  }
}

// How much memory (roughly) does a disjoint_union_data instance consume? I guess the Ruby runtime can use this information when
// deciding how agressive to be during garbage collection and such.
static size_t disjoint_union_memsize(const void *ptr) {
  //printf("In disjoint_union_memsize\n");
  if (ptr) {
    const disjoint_union_data *disjoint_union = ptr;
    return (2 * disjoint_union->forest->size * sizeof(long));
  } else {
    return 0;
  }
}

/************************************************************
 * Setup for the Ruby Runtime and object initialization
 *************************************************************
 */

#define GetDisjointUnion(object, disjoint_union) TypedData_Get_Struct((object), disjoint_union_data, &disjoint_union_type, (disjoint_union));

/*
 * A struct of configuration that tells the Ruby runtime how to deal with a disjoint_union_data object.
 *
 * https://docs.ruby-lang.org/en/master/extension_rdoc.html#label-Encapsulate+C+data+into+a+Ruby+object
 */
static const rb_data_type_t disjoint_union_type = {
  .wrap_struct_name = "disjoint_union",
  { // help for the Ruby garbage collector
    .dmark = NULL, // dmark, for marking other Ruby objects
    .dfree = disjoint_union_free,
    .dsize = disjoint_union_memsize,
  },
  .data = NULL, // a data field we could use for something here if we wanted. Ruby ignores it
  .flags = 0  // GC-related flag values.
};



/************************************************************
 * C implementation of the Disjoint Union functionality
 ************************************************************/

// Is the given element already a member of the Disjoint Union's universe?
static int present_p(disjoint_union_data* disjoint_union, size_t element) {
  Array* forest = disjoint_union->forest;
  return (forest->size > element && (forest->array[element] != DEFAULT_ARRAY_VAL));
}

static void check_membership(disjoint_union_data* disjoint_union, size_t element) {
  if (!present_p(disjoint_union, element)) {
    rb_raise(eDataError, "Value %zu is not part of the universe", element);
  }
}

// Add a new subset containing just the given element
static void add_new_element(disjoint_union_data* disjoint_union, size_t element) {
  if (element < 0) {
    rb_raise(rb_eArgError, "New element cannot be negative");
  }

  Array* d = disjoint_union->forest;

  if (present_p(disjoint_union, element)) {
    rb_raise(rb_eArgError, "Element %zu already present in the universe (array has val %zu)", element, d->array[element]);
  }

  insertArray(disjoint_union->forest, element, element);
  insertArray(disjoint_union->rank, element, 0);
  disjoint_union->subset_count++;
}

// Find the canonical representative of the given element. Two elements are in the same subset exactly when their canonical
// representatives are equal.
static size_t find(disjoint_union_data* disjoint_union, size_t element) {
  check_membership(disjoint_union, element);

  // We implement find with "halving" to shrink the length of paths to the root. See Tarjan and van Leeuwin p 252.
  long* d = disjoint_union->forest->array; // the actual forest data
  size_t x = element;
  while (d[d[x]] != d[x]) {
    x = d[x] = d[d[x]];
  }
  return d[x];
}

static void link_roots(disjoint_union_data* disjoint_union, size_t elt1, size_t elt2) {
  long* rank = disjoint_union->rank->array;
  long* forest = disjoint_union->forest->array;

  if (rank[elt1] > rank[elt2]) {
    forest[elt2] = elt1;
  } else if (rank[elt1] == rank[elt2]) {
    forest[elt2] = elt1;
    rank[elt1]++;
  } else {
    forest[elt1] = elt2;
  }

  disjoint_union->subset_count--;
}

static void unite(disjoint_union_data* disjoint_union, size_t elt1, size_t elt2) {
  check_membership(disjoint_union, elt1);
  check_membership(disjoint_union, elt2);

  if (elt1 == elt2) {
    rb_raise(eDataError, "Uniting an element with itself is meaningless");
  }

  size_t root1 = find(disjoint_union, elt1);
  size_t root2 = find(disjoint_union, elt2);

  if (root1 == root2) {
    return; // already united
  }

  link_roots(disjoint_union, root1, root2);
}


/************************************************************
 * VALUE wrapper and unwrappers for the Ruby interface
 ************************************************************/

// Implement Class#allocate for CDisjointUnion
static VALUE disjoint_union_alloc(VALUE klass) {
  //printf("In disjoint_union_alloc\n");

  disjoint_union_data* disjoint_union = malloc(sizeof(disjoint_union_data));
  //printf("...just mallocked for a disjoint union at %p\n", (void*) disjoint_union);

  // Allocate the structures
  Array* forest = malloc(sizeof(Array));
  Array* rank = malloc(sizeof(Array));
  initArray(forest, 100, -1);
  initArray(rank, 100, 0);

  disjoint_union->forest = forest;
  disjoint_union->rank = rank;
  disjoint_union->subset_count = 0;

  // Wrap
  return TypedData_Wrap_Struct(klass, &disjoint_union_type, disjoint_union);
}

// This is CDisjointUnion#initialize
static VALUE disjoint_union_init(int argc, VALUE *argv, VALUE self) {
  //printf("In disjoint_union_init\n");
  if (argc == 0) {
    return self;
  } else if (argc > 1) {
    rb_raise(rb_eArgError, "wrong number of arguments");
  } else {
    Check_Type(argv[0], T_FIXNUM);

    size_t initial_size = FIX2LONG(argv[0]);
    if (initial_size < 0) {
      rb_raise(rb_eArgError, "Initial size must be non-negative");
    }

    // Unwrap
    disjoint_union_data* disjoint_union;
    GetDisjointUnion(self, disjoint_union);
    //TypedData_Get_Struct(self, disjoint_union_data, &disjoint_union_type, disjoint_union);

    for (size_t i = 0; i < initial_size; i++)
      add_new_element(disjoint_union, i);
  }
  return self;
}

static VALUE disjoint_union_make_set(VALUE self, VALUE arg) {
  disjoint_union_data* disjoint_union;
  GetDisjointUnion(self, disjoint_union);
  Check_Type(arg, T_FIXNUM);

  add_new_element(disjoint_union, FIX2LONG(arg));
  return Qnil;
}

static VALUE disjoint_union_subset_count(VALUE self) {
  disjoint_union_data* disjoint_union;
  GetDisjointUnion(self, disjoint_union);

  return LONG2NUM(disjoint_union->subset_count);
}

static VALUE disjoint_union_find(VALUE self, VALUE arg) {
  disjoint_union_data* disjoint_union;
  GetDisjointUnion(self, disjoint_union);
  Check_Type(arg, T_FIXNUM);

  return LONG2NUM(find(disjoint_union, FIX2LONG(arg)));
}

static VALUE disjoint_union_unite(VALUE self, VALUE arg1, VALUE arg2) {
  disjoint_union_data* disjoint_union;
  GetDisjointUnion(self, disjoint_union);

  Check_Type(arg1, T_FIXNUM);
  Check_Type(arg2, T_FIXNUM);

  unite(disjoint_union, FIX2LONG(arg1), FIX2LONG(arg2));

  return Qnil;
}

/************************************************************
 * Set things up
 ************************************************************/
void Init_CDisjointUnion() {
  mDataStructuresRMolinari = rb_define_module("DataStructuresRMolinari");
  mShared = rb_define_module("Shared");
  id_DataError = rb_intern_const("DataError");

  // for now we work on a separate class, CDisjointUnion
  cDisjointUnion = rb_define_class_under(mDataStructuresRMolinari, "CDisjointUnion", rb_cObject);

  rb_define_alloc_func(cDisjointUnion, disjoint_union_alloc);
  rb_define_method(cDisjointUnion, "initialize", disjoint_union_init, -1);
  rb_define_method(cDisjointUnion, "make_set", disjoint_union_make_set, 1);
  rb_define_method(cDisjointUnion, "subset_count", disjoint_union_subset_count, 0);
  rb_define_method(cDisjointUnion, "find", disjoint_union_find, 1);
  rb_define_method(cDisjointUnion, "unite", disjoint_union_unite, 2);
}
