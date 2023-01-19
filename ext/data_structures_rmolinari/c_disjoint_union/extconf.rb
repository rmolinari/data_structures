require 'mkmf'

abort 'missing malloc()' unless have_func "malloc"
abort 'missing realloc()' unless have_func "realloc"

extension_name = "CDisjointUnion"
dir_config(extension_name)
create_makefile(extension_name)
