#ifndef DYNAMIC_ARRAY_H
#define DYNAMIC_ARRAY_H

/**
 * Dynamic array with an initial value for otherwise uninitialized elements.
 *
 * Based on https://stackoverflow.com/questions/3536153/c-dynamically-growing-array (but all the "generic" crap piled on top is
 * mine).
 *
 *
 * There are several parts to the Dynamic Array:
 *
 * The struct, of type name DynamicArray_<type>. It looks like
 *
 * typedef struct {
 *   <type> *array;
 *   size_t size;
 *   <type> default_val;
 * } DynamicArray_<type>;
 *
 *
 * Functions:
 * - initDynamicArray_<type>(DynamicArray_<type> *a, size_t initial_size, <type> defvault_val)
 *   - Initialize a DynamicArray struct with the given initial size and with all values set to the default value. The default value
 *     is stored and used to initialize new array sections if and when the array needs to be expanded.
 *
 * - void assignInDynamicArray_<type>(DynamicArray_<type> *a, unsigned long index, <type> value)
 *   - Assign +value+ to the the +index+-th element of the array, expanding the available space if necessary.
 *
 * - void freeDynamicArray_<type>(DynamicArray_<type> *a)
 *   - Free the heap memory associated with the object.
 *
 * - size_t _size_of_<type>(DynamicArray_<type> *a)
 *   - Return the amount of heap space allocated for the object. This might be useful to the Ruby runtime.
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
 *   - maybe it would be simpler to use a different preprocessor to generate sourcefiles from a template and do things via the Makefile.
 */

/*
 * The name of the type being defined.
 *
 * For example, when defining a dynamic array storing longs, this will be DynamicArray_long
 */
#define __DA_TYPE(type) DynamicArray_##type

/*
 * Code fo a dynamic array storing elements of the given type.
 */
#define DYNAMIC_ARRAY_OF(type)                                                                                                      \
typedef struct {                                                                                                                    \
  type *array;                                                                                                                      \
  size_t size;                                                                                                                      \
  type default_val;                                                                                                                 \
} __DA_TYPE(type);                                                                                                                  \
                                                                                                                                    \
void initDynamicArray_##type(__DA_TYPE(type) *a, size_t initial_size, long default_val) {                                           \
  a->array = malloc(initial_size * sizeof(long));                                                                                   \
  a->size = initial_size;                                                                                                           \
  a->default_val = default_val;                                                                                                     \
                                                                                                                                    \
  for (size_t i = 0; i < initial_size; i++) {                                                                                       \
    a->array[i] = default_val;                                                                                                      \
  }                                                                                                                                 \
}                                                                                                                                   \
                                                                                                                                    \
void assignInDynamicArray_##type(__DA_TYPE(type) *a, unsigned long index, long value) {                                             \
  if (a->size <= index) {                                                                                                           \
    size_t new_size = a->size;                                                                                                      \
    while (new_size <= index) {                                                                                                     \
      new_size = 8 * new_size / 5 + 8; /* 8/5 gives "Fibonnacci-like" growth; adding 8 to avoid small arrays having to reallocate   \
                                        * too often as they grow. Who knows if it's worth being "clever".*/                         \
    }                                                                                                                               \
                                                                                                                                    \
    long *new_array = realloc(a->array, new_size * sizeof(long));                                                                   \
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
void freeDynamicArray_##type(__DA_TYPE(type) *a) {                                                                                  \
  free(a->array);                                                                                                                   \
  a->array = NULL;                                                                                                                  \
  a->size = 0;                                                                                                                      \
}                                                                                                                                   \
                                                                                                                                    \
size_t _size_of_##type(__DA_TYPE(type) *a) {                                                                                        \
  return sizeof(__DA_TYPE(type)) + a->size * sizeof(a->default_val);                                                                \
}

/*
 * Some helpers to strip off the _<type> suffixes in client code where possible. This uses the _Generic feature from C11.
 *
 * For example, when a DynamicArray_long is defined, we can drop the "_long" when calling the functions (though not from the struct
 * name).
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
