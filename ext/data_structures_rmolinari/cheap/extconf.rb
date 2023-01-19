require 'mkmf'

# abort 'missing return_nil()' unless have_func "return_nil"

extension_name = "CHeap"
dir_config(extension_name)
create_makefile(extension_name)
