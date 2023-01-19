#include "ruby.h"

static VALUE mDataStructuresRMolinari;
static VALUE cDisjointUnion;

/**
 * It's been so long since I've written non-trival C that I need to copy examples from online
 * Dynamic array of longs, with initial values of -1.

 * Based on  https://stackoverflow.com/questions/3536153/c-dynamically-growing-array
 */
#define DEFAULT_ARRAY_VAL -1L
typedef struct {
  long *array;
  size_t size;
} Array;

void initArray(Array *a, size_t initial_size) {
  //printf("In initArray with initial_size=%zu\n", initial_size);
  a->array = malloc(initial_size * sizeof(long));
  //printf("... just allocated array %p\n", (void *) a->array);
  a->size = initial_size;

  for (unsigned long i = 0; i < initial_size; i++) {
    //printf("Setting a->array[%lu] = %li\n", i, DEFAULT_ARRAY_VAL);
    a->array[i] = DEFAULT_ARRAY_VAL;
  }

  //printf("...done with initArray. a->size=%zu\n", a->size);
}

void insertArray(Array *a, long element, unsigned long index) {
  //printf("In insertArray for index %zu, size=%zu\n", index, a->size );
  if (a->size < index) {
    size_t new_size = a->size;
    while (new_size < index) {
      new_size *= 2;
    }
    long* new_array = realloc(a->array, new_size * sizeof(long));
    if (!new_array) {
      rb_raise(rb_eRuntimeError, "Cannot allocate memory to expand Array!");
    }
    a->array = new_array;
    for (size_t i = a->size; i < new_size; i++) {
      // printf("Setting a->array[%zu] = %li", i, DEFAULT_ARRAY_VAL);
      a->array[i] = DEFAULT_ARRAY_VAL;
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

/** END simple dynamic array */

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
  Array* data;
  size_t subset_count;
} disjoint_union_data;

// Free a DisjointUnion struct for the Ruby GC
static void disjoint_union_free(void *ptr) {
  //printf("In disjoint_union_free for pointer %p\n", ptr);
  if (ptr) {
    disjoint_union_data *disjoint_union = ptr;
    //printf("   In disjoint_union_free...about to call freeArray\n");
    freeArray(disjoint_union->data);
    free(disjoint_union->data);
    free(ptr);
  }
}

// How much memory (roughly) does a disjoint_union_data instance consume? I guess the Ruby runtime can use this information when
// deciding how agressive to be during garbage collection and such.
static size_t disjoint_union_memsize(const void *ptr) {
  //printf("In disjoint_union_memsize\n");
  if (ptr) {
    const disjoint_union_data *disjoint_union = ptr;
    return (disjoint_union->data->size * sizeof(long));
  } else {
    return 0;
  }
}

/************************************************************
 * Setup for the Ruby Runtime and object initialization
 *************************************************************
 */

#define GetDisjointUnion(object, disjoin_union) TypedData_Get_Struct((object), disjoint_union_data, &disjoint_union_type, (disjoint_union));

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


// Implement Class#allocate for CDisjointUnion
static VALUE disjoint_union_alloc(VALUE klass) {
  //printf("In disjoint_union_alloc\n");

  disjoint_union_data* disjoint_union = malloc(sizeof(disjoint_union_data));
  //printf("...just mallocked for a disjoint union at %p\n", (void*) disjoint_union);

  // Allocate the structures
  Array* data = malloc(sizeof(Array));
  initArray(data, (size_t)100);

  disjoint_union->data = data;
  disjoint_union->subset_count = 0;

  // Wrap
  return TypedData_Wrap_Struct(klass, &disjoint_union_type, disjoint_union);
}

static void add_new_element(disjoint_union_data*, size_t);

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

/************************************************************
 * Accessors and mutators
 ************************************************************/

// Internal code that adds a new set containing just the given element
static void add_new_element(disjoint_union_data* disjoint_union, size_t element) {
  if (element < 0) {
    rb_raise(rb_eArgError, "New element cannot be negative");
  }

  Array* d = disjoint_union->data;

  if (d->size > element && (d->array[element] != DEFAULT_ARRAY_VAL)) {
    rb_raise(rb_eArgError, "Element %zu already present in the universe (array has val %zu)", element, d->array[element]);
  }

  insertArray(disjoint_union->data, element, element);
  disjoint_union->subset_count++;
}

static VALUE disjoint_union_make_set(VALUE self, VALUE arg) {
  disjoint_union_data* disjoint_union;
  GetDisjointUnion(self, disjoint_union);
  Check_Type(arg, T_FIXNUM);
  size_t new_element = FIX2LONG(arg);

  add_new_element(disjoint_union, new_element);

  return Qnil;
}

static VALUE disjoint_union_subset_count(VALUE self) {
  disjoint_union_data* disjoint_union;
  GetDisjointUnion(self, disjoint_union);

  return LONG2NUM(disjoint_union->subset_count);
}


/************************************************************
 * Set things up
 ************************************************************/
void Init_CDisjointUnion() {
  mDataStructuresRMolinari = rb_define_module("DataStructuresRMolinari");
  // for now we work on a separate class, CDisjointUnion
  cDisjointUnion = rb_define_class_under(mDataStructuresRMolinari, "CDisjointUnion", rb_cObject);

  rb_define_alloc_func(cDisjointUnion, disjoint_union_alloc);
  rb_define_method(cDisjointUnion, "initialize", disjoint_union_init, -1);
  rb_define_method(cDisjointUnion, "make_set", disjoint_union_make_set, 1);
  rb_define_method(cDisjointUnion, "subset_count", disjoint_union_subset_count, 0);
}
