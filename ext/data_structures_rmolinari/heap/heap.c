#include "ruby.h"
#include "extconf.h"

VALUE rb_return_nil() {
  return Qnil;
}

static VALUE mDataStructuresRMolinari;
static VALUE cHeap;

void Init_CHeap() {
  mDataStructuresRMolinari = rb_define_module("DataStructuresRMolinari");
  cHeap = rb_define_class_under(mDataStructuresRMolinari, "Heap", rb_cObject); // define a method on the Heap class

  rb_define_method(cHeap, "return_nil", rb_return_nil, 0);
}
