def generate_makefile(name)
  extension_name = "c_#{name}"
  source_name = "#{name}.c"

  abort 'missing malloc()' unless have_func "malloc"
  abort 'missing realloc()' unless have_func "realloc"

  if try_cflags('-O3')
    append_cflags('-O3')
  end

  dir_config(extension_name)

  $srcs = [source_name, "../shared.c"]
  $INCFLAGS << " -I$(srcdir)/.."
  $VPATH << "$(srcdir)/.."

  create_makefile("data_structures_rmolinari/#{extension_name}")
end
