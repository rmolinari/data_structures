require 'rubygems'
require 'rake/testtask'
require 'rake/extensiontask'

['c_disjoint_union', 'c_segment_tree_template'].each do |extension_name|
  Rake::ExtensionTask.new("data_structures_rmolinari/#{extension_name}") do |ext|
    ext.name = extension_name
    ext.ext_dir = "ext/#{extension_name}"
    ext.lib_dir = 'lib/data_structures_rmolinari/'
  end
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run Tests'
task default: :test
