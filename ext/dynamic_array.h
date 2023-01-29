#ifndef DYNAMIC_ARRAY_H
#define DYNAMIC_ARRAY_H

/**
 * Dynamic array with an initial value for otherwise uninitialized elements.
 *
 * Based on https://stackoverflow.com/questions/3536153/c-dynamically-growing-array (but all the "generic" crap piled on top is
 * mine).
 *
 * NOTE:
 * ----
 *
 * I am experimenting with a low-budget "generic" approach using a macro to paste in the desired type everywhere. I don't think this
 * is best-practice C but I'm interested to see how it works.
 *
 * Findings
 * - there will be a problem with duplicated code if two files each use DYNAMIC_ARRAY_OF(the_same_type). I'm sure the linker will
 *   complain.
 *   - note that we can't use the preprocessor to avoid defining everything multiple times because we can't nest #defines.
 *   - maybe it would be simpler to use a different preprocessor to generate sourcefiles from a template and do things via the
 *     Makefile.
 *     - ugh :(
 */

/*
 * The name of the type being defined.
 *
 * For example, when defining a dynamic array storing longs, this will be DynamicArray_long.
 *
 * See below for the need for different handling for, say, __DA_TYPE(unsigned long).
 */
#define __DA_TYPE(type) DynamicArray_##type

/*
 * Code for a dynamic array storing elements of the given type.
 *
 * Note the interaction between the macro and embedded C comments. The preprocessor elminates comments in phase 3 - replacing each
 * with a single space - and expands macros in phase 4. Thus each multi-line comment below is the same as a space so far as the
 * macro is concerned. Having backslashes in the comments themselves causes some sort of other problem. Thus, although it looks like
 * the macro expansion text ends with the first comment, it doesn't.
 *
 * Reference: https://stackoverflow.com/questions/1510869/does-the-c-preprocessor-strip-comments-or-expand-macros-first
 *
 * TODO:
 * - handle types with spaces, like "unsigned long", or with non-alphanumerics, like "void *".
 *   - presuambly we need a second argument, suffix, for use in identifiers. Client code can provide, say, "ulong" and "void_ptr"
 *   - for standard types we could use _Generic along the lines of Alex Grey's answer here:
 *     https://stackoverflow.com/questions/9804371/syntax-and-sample-usage-of-generic-in-c11
 *     - Then, if this is DEFINE_DYNAMIC_ARRAY_OF2(type, suffix), we could define a macro TYPE_SUFFIX(type) using _Generic and
 *       then do
 *
 *         #define DEFINE_DYNAMIC_ARRAY_OF(type) DEFINE_DYNAMIC_ARRAY_OF2(type, TYPE_SUFFIX(type))
 */
#define DEFINE_DYNAMIC_ARRAY_OF(type)                                                                                               \
typedef struct {                                                                                                                    \
  type *array;                                                                                                                      \
  size_t size;                                                                                                                      \
  type default_val;                                                                                                                 \
} __DA_TYPE(type);                                                                                                                  \
                                                                                                                                    \
/*
 * Initialize an already-allocated DynamicArray struct with the given initial size and with all elements set to the default
 * value. The default value is stored and used to initialize new array sections if and when the array needs to be expanded.
 */                                                                                                                                 \
void initDynamicArray_##type(__DA_TYPE(type) *a, size_t initial_size, type default_val) {                                           \
  a->array = malloc(initial_size * sizeof(type));                                                                                   \
  a->size = initial_size;                                                                                                           \
  a->default_val = default_val;                                                                                                     \
                                                                                                                                    \
  for (size_t i = 0; i < initial_size; i++) {                                                                                       \
    a->array[i] = default_val;                                                                                                      \
  }                                                                                                                                 \
}                                                                                                                                   \
                                                                                                                                    \
/*
 * Assign +value+ to the the +index+-th element of the array, increasing the size of the array if necessary.
 *
 * If expansion is required, each new element is first initialized to the default value.
 */                                                                                                                                 \
void assignInDynamicArray_##type(__DA_TYPE(type) *a, size_t index, type value) {                                                    \
  if (a->size <= index) {                                                                                                           \
    size_t new_size = a->size;                                                                                                      \
    while (new_size <= index) {                                                                                                     \
      /*
       * 8/5 gives "Fibonnacci-like" growth; adding 8 avoids small arrays having to reallocate too often as they grow. Who knows if
       * it's worth being "clever".
       */                                                                                                                           \
      new_size = 8 * new_size / 5 + 8;                                                                                              \
    }                                                                                                                               \
                                                                                                                                    \
    type *new_array = realloc(a->array, new_size * sizeof(type));                                                                   \
    if (!new_array) {                                                                                                               \
      rb_raise(rb_eRuntimeError, "Cannot allocate memory to expand DynamicArray_##type!");                                          \
    }                                                                                                                               \
                                                                                                                                    \
    a->array = new_array;                                                                                                           \
    for (size_t i = a->size; i < new_size; i++) {                                                                                   \
      a->array[i] = a->default_val;                                                                                                 \
    }                                                                                                                               \
                                                                                                                                    \
    a->size = new_size;                                                                                                             \
  }                                                                                                                                 \
                                                                                                                                    \
  a->array[index] = value;                                                                                                          \
}                                                                                                                                   \
                                                                                                                                    \
/*
 * Free the heap memory associated with the object.
 */                                                                                                                                 \
void freeDynamicArray_##type(__DA_TYPE(type) *a) {                                                                                  \
  free(a->array);                                                                                                                   \
  a->array = NULL;                                                                                                                  \
  a->size = 0;                                                                                                                      \
}                                                                                                                                   \
                                                                                                                                    \
/*
 * Return the amount of heap space allocated for the object, including the object itself. This might be useful to the Ruby runtime.
 */                                                                                                                                 \
size_t _size_of_##type(__DA_TYPE(type) *a) {                                                                                        \
  return sizeof(a) + a->size * sizeof(type);                                                                                        \
}

/*
 * Some helpers to strip off the _<type> suffixes in client code where possible. This uses the _Generic feature from C11.
 *
 * For example, when a DynamicArray_long is defined, we can drop the "_long" when calling the functions (though not from the struct
 * name).
 *
 * Client code using a type we don't know about will need to #define these itself.
 */
#define initDynamicArray(a, initial_size, default_val)                                                                              \
  _Generic((a),                                                                                                                     \
           __DA_TYPE(long)* : initDynamicArray_long)((a), (initial_size), (default_val))

#define assignInDynamicArray(a, index, value)                                                                                       \
  _Generic((a),                                                                                                                     \
           __DA_TYPE(long)* : assignInDynamicArray_long)((a), (index), (value))

#define freeDynamicArray(a)                                                                                                         \
  _Generic((a),                                                                                                                     \
           __DA_TYPE(long)* : freeDynamicArray_long)((a))

#define _size_of(a)                                                                                                                 \
  _Generic((a),                                                                                                                     \
           __DA_TYPE(long)* : _size_of_long)((a))

#endif
