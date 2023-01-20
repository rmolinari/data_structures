require 'rubygems'
require 'rake/testtask'
require 'rake/extensiontask'

Rake::ExtensionTask.new('data_structures_rmolinari/c_disjoint_union') do |ext|
  ext.name = 'CDisjointUnion'
  ext.ext_dir = 'ext/data_structures_rmolinari/c_disjoint_union'
  ext.lib_dir = 'lib/data_structures_rmolinari/'
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run Tests'
task default: :test
