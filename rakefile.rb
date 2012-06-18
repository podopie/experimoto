require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*test*.rb']
  t.verbose = true
end

task :archive do
  system('git archive master | bzip2 >source-tree.tar.bz2')
end

