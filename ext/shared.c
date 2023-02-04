#include "ruby.h"
#include "shared.h"

/*
 * Arithmetic for in-array binary tree
 */
size_t midpoint(size_t left, size_t right) {
  return (left + right) / 2;
}

size_t left_child(size_t i) {
  return i << 1;
}

size_t right_child(size_t i) {
  return 1 + (i << 1);
}

/*
 * Check that a Ruby value is a non-negative Fixnum and convert it to a C unsigned long
 */
unsigned long checked_nonneg_fixnum(VALUE val) {
  Check_Type(val, T_FIXNUM);
  long c_val = FIX2LONG(val);

  if (c_val < 0) {
    rb_raise(eSharedDataError, "Value must be non-negative");
  }

  return c_val;
}


