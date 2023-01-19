#include "ruby.h"

#define size FIX2LONG(rb_iv_get(self, "@size"))
#define data rb_iv_get(self, "@data")
#define eDataError rb_const_get(cHeap, id_DataError)

static ID id_DataError;
static VALUE mDataStructuresRMolinari;
static VALUE cHeap;

VALUE rb_return_nil() {
  return Qnil;
}

// Do what the regular Heap#top does, as a learning exercise.
VALUE rb_top(VALUE self) {
  /*   raise 'Heap is empty!' unless @size.positive? */
  /*   @data[root].item */
  if (size == 0) {
    rb_raise(eDataError, "Heap is empty!");
  }

  /*
   * rb_funcall takes the receiver, a symbol type thing for the method, the argument count, and then the arguments.
   * We can get the symbol type thing we need for the method name by calling rb_intern.
   */
  return rb_funcall(rb_ary_entry(data, 1), rb_intern("item"), 0);
}

void Init_CHeap() {
  mDataStructuresRMolinari = rb_define_module("DataStructuresRMolinari");
  cHeap = rb_define_class_under(mDataStructuresRMolinari, "Heap", rb_cObject); // we will define methods on the Heap class
  // eDataError = rb_define_class_under(cHeap, "DataError", rb_eStandardError);
  id_DataError = rb_intern_const("DataError");

  rb_define_method(cHeap, "return_nil", rb_return_nil, 0);
  rb_define_method(cHeap, "ctop", rb_top, 0);
}
