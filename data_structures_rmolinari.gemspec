Gem::Specification.new do |s|
  s.name        = 'data_structures_rmolinari'
  s.version     = '0.1.0'
  s.summary     = 'Several miscellaneous data structures I have implemented to learn about them.'
  s.description = <<~DESC
    This small gem contains several data structures that I have implemented to learn how they work.

    Sometimes it is not enough to read the description of a data structure and accompanying pseudo-code.
    Actually implementing the structure is often helpful in understanding what is going on. It is also
    usually fun.
  DESC
  s.authors     = ['Rory Molinari']
  s.email       = 'rorymolinari+rubygems@gmail.com'
  s.files       = [
    'lib/data_structures_rmolinari.rb',
    'lib/data_structures_rmolinari/max_priority_search_tree_internal.rb',
    'lib/data_structures_rmolinari/minmax_priority_search_tree_internal.rb',
    'lib/data_structures_rmolinari/shared.rb'
  ]
  s.license     = 'MIT'
  s.required_ruby_version = '3.1.3'

  s.add_runtime_dependency 'must_be', '~> 1.1.0'

  s.add_development_dependency 'byebug', '~> 11.1.3'
  s.add_development_dependency 'ruby-prof', '~> 1.4.5'
  s.add_development_dependency 'simplecov', '~> 0.22.0'
end
