require 'mkmf'

abort 'missing malloc()' unless have_func "malloc"
abort 'missing realloc()' unless have_func "realloc"

if try_cflags('-O')
  append_cflags('-O')
end

extension_name = "c_disjoint_union"
dir_config(extension_name)
create_makefile("data_structures_rmolinari/c_disjoint_union")
