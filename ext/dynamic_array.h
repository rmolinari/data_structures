#ifndef DYNAMIC_ARRAY_H
#define DYNAMIC_ARRAY_H

/**
 * Dynamic array of longs, with an initial value for otherwise uninitialized elements.
 * Based on  https://stackoverflow.com/questions/3536153/c-dynamically-growing-array
 */
typedef struct {
  long *array;
  size_t size;
  long default_val;
} DynamicArray;

/*
 * Initialize a DynamicArray struct with the given initial size and with all values set to the default value.
 *
 * The default value is stored and used to initialize new array sections if and when the array needs to be expanded.
 */
void initDynamicArray(DynamicArray *a, size_t initial_size, long default_val);

/*
 * Assign +value+ to the the +index+-th element of the array, expanding the available space if necessary.
 */
void assignInDynamicArray(DynamicArray *a, unsigned long index, long value);

/*
 * Free the memory associated with a DynamicArray
 */
void freeDynamicArray(DynamicArray *a);

/*
 * The size consumed by a DynamicArray. This is sometimes useful during Ruby debugging and profiling.
 */
size_t _size_of(DynamicArray *a);

#endif
