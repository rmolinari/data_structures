require 'rake/testtask'
require 'rake/extensiontask'

Rake::ExtensionTask.new('data_structures_rmolinari/c_disjoint_union') { |ext| ext.name = 'CDisjointUnion' }

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run Tests'
task default: :test
