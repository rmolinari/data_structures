#include <stddef.h>
#include <stdlib.h>

#include "ruby.h"
#include "dynamic_array.h"

/**
 * Dynamic array of longs, with an initial value for otherwise uninitialized elements.
 * Based on  https://stackoverflow.com/questions/3536153/c-dynamically-growing-array
 */
/*
 * Initialize a DynamicArray struct with the given initial size and with all values set to the default value.
 *
 * The default value is stored and used to initialize new array sections if and when the array needs to be expanded.
 */
void initDynamicArray(DynamicArray *a, size_t initial_size, long default_val) {
  a->array = malloc(initial_size * sizeof(long));
  a->size = initial_size;
  a->default_val = default_val;

  for (size_t i = 0; i < initial_size; i++) {
    a->array[i] = default_val;
  }
}

/*
 * Assign +value+ to the the +index+-th element of the array, expanding the available space if necessary.
 */
void assignInDynamicArray(DynamicArray *a, unsigned long index, long value) {
  if (a->size <= index) {
    size_t new_size = a->size;
    while (new_size <= index) {
      new_size = 8 * new_size / 5 + 8; // 8/5 gives "Fibonnacci-like" growth; adding 8 to avoid small arrays having to reallocate
                                       // too often as they grow. Who knows if it's worth being "clever".
    }

    long *new_array = realloc(a->array, new_size * sizeof(long));
    if (!new_array) {
      rb_raise(rb_eRuntimeError, "Cannot allocate memory to expand DynamicArray!");
    }

    a->array = new_array;
    for (size_t i = a->size; i < new_size; i++) {
      a->array[i] = a->default_val;
    }

    a->size = new_size;
  }

  a->array[index] = value;
}

void freeDynamicArray(DynamicArray *a) {
  free(a->array);
  a->array = NULL;
  a->size = 0;
}

size_t _size_of(DynamicArray *a) {
  return a->size * sizeof(a->default_val);
}

