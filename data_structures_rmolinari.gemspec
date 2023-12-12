require 'rake'

Gem::Specification.new do |s|
  s.name        = 'data_structures_rmolinari'
  s.version     = '0.5.4'
  s.summary     = 'Several miscellaneous data structures I have implemented to learn about them.'
  s.description = <<~DESC
    This small gem contains several data structures that I have implemented in Ruby to learn how they work.

    Sometimes it is not enough to read the description of a data structure and accompanying pseudo-code.
    Actually implementing it is often helpful in understanding what is going on. It is also
    usually fun.

    The gem contains basic implementions of Disjoint Union, Heap, Priority Search Tree, and Segment Tree.
    See the homepage for more details.
  DESC
  s.authors     = ['Rory Molinari']
  s.email       = 'rorymolinari@gmail.com'
  s.homepage    = 'https://github.com/rmolinari/data_structures'
  s.files       = FileList['lib/**/*.rb', 'ext/**/*.c', 'ext/**/*.h', 'ext/**/*rb', 'CHANGELOG.md', 'README.md', 'Rakefile']
  s.extensions  = FileList['ext/**/extconf.rb']
  s.license     = 'MIT'
  s.required_ruby_version = '~> 3.1.3'

  s.add_runtime_dependency 'must_be', '~> 1.1.0'

  s.add_development_dependency 'byebug', '~> 11.1.3'
  s.add_development_dependency 'ruby-prof', '~> 1.4.5'
  s.add_development_dependency 'simplecov', '~> 0.22.0'
end
