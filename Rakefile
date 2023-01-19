require 'rake/testtask'
require 'rake/extensiontask'

Rake::ExtensionTask.new('data_structures_rmolinari/heap') do |ext|
  ext.name = 'CHeap'
  ext.lib_dir = 'lib/data_structures_rmolinari'
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run Tests'
task default: :test
