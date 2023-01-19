require 'rake/testtask'
require 'rake/extensiontask'

Rake::ExtensionTask.new('data_structures_rmolinari/cheap') do |ext|
  ext.name = 'CHeap'
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run Tests'
task default: :test
