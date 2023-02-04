#ifndef SHARED_H
#define SHARED_H

#include <stddef.h>

#define mShared rb_define_module("Shared")
#define eSharedDataError rb_const_get(mShared, rb_intern_const("DataError"))
#define eSharedInternalLogicError rb_const_get(mShared, rb_intern_const("InternalLogicError"))
#define mDataStructuresRMolinari rb_define_module("DataStructuresRMolinari")

//#define debug(...) printf(__VA_ARGS__)
#define debug(...)

/* What we might think of as vector[index] for a CC vec(foo). It is assignable */
#define lval(vector, index) (*get(vector, index))

/*
 * Binary tree arithmetic for an implicit tree in an array, 1-based.
 */
#define TREE_ROOT 1
size_t midpoint(size_t left, size_t right);
size_t left_child(size_t i);
size_t right_child(size_t i);

/*
 * Check that a Ruby value is a non-negative Fixnum and convert it to a C unsigned long
 */
unsigned long checked_nonneg_fixnum(VALUE val);

#endif
