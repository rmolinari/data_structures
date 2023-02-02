require 'mkmf'

abort 'missing malloc()' unless have_func "malloc"
abort 'missing realloc()' unless have_func "realloc"

# if try_cflags('-O3')
#   append_cflags('-O3')
# end

extension_name = "c_segment_tree_template"
dir_config(extension_name)
create_makefile("data_structures_rmolinari/c_segment_tree_template")
