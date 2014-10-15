
$LOAD_PATH.unshift File.dirname(__FILE__) + "/lib"

require 'rubygems'
require 'bundler/setup'
require "bundler/gem_tasks"
require 'rdoc'
require 'rdoc/markup'
require 'rdoc/markup/formatter'
require 'rdoc/markup/to_ansi'
require 'rake/testtask'
require 'ci/reporter/rake/test_unit_loader'

require 'fileutils'
require 'flare/tools'

Dir['tasks/**/*.rake'].each { |t| load t }

task :default => [:test]

task :help do
  print <<EOS
Examples:
  run a specific test script
  > rake test TEST=testname_test.rb
  run a specific test
  > rake test TESTOPTS=--name=test_mytest1
  run tests with --verbose
  > rake test TESTOPTS=--verbose
  run stress tests
  > rake test FLARE_TOOLS_STRESS_TEST=yes
EOS
end

task :manual do
  h = RDoc::Markup::ToAnsi.new
  rdoc = File.read("README.txt")
  puts h.convert(rdoc)
end

Rake::TestTask.new do |test|
  test.libs << './lib'
  test.test_files = Dir['test/unit/**/*_test.rb', 'test/integration/**/*_test.rb', 'test/system/**/*_test.rb']
  test.verbose = true
  test.ruby_opts = ['-r', 'rubygems']
end

task :test => :work

directory "work"

task :clean do
 sh "rm -rf test/work/test*"
 sh "rm -f test/*~"
 sh "rm -f /tmp/flare[id].*.conf"
end

task :debuild do |t|
  sh "debuild -us -uc"
end

task :debclean do
  sh "debclean"
  sh "(cd .. && rm -f *.dsc *.tar.gz *.build *.changes)"
  sh "rm -f debian/changelog.dch"
end

def previous version
  prev = version.split('.').map{|v| v.to_i}
  prev[2] -= 1
  prev.join('.')
end

task :change do
  puts "================================="
  puts "  Flare::Tools::VERSION = #{Flare::Tools::VERSION}"
  puts "================================="
  debian_branch = ENV["DEBIAN_BRANCH"] || "(no branch)"
  version = Flare::Tools::VERSION
  since = previous version
  sh "git-dch --debian-branch='#{debian_branch}' --new-version #{version} --since=#{since}"
end

task :killall do
 sh "pkill /usr/local/bin/flarei"
 sh "pkill /usr/local/bin/flared"
end

task :cleanall => [:clean] do
end


