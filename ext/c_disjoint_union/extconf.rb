require 'mkmf'

abort 'missing malloc()' unless have_func "malloc"
abort 'missing realloc()' unless have_func "realloc"

if try_cflags('-O3')
  append_cflags('-O3')
end

extension_name = "c_disjoint_union"
dir_config(extension_name)

$srcs = ["disjoint_union.c", "../shared.c"]
$INCFLAGS << " -I$(srcdir)/.."
$VPATH << "$(srcdir)/.."

create_makefile("data_structures_rmolinari/c_disjoint_union")
