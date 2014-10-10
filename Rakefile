
$LOAD_PATH.unshift File.dirname(__FILE__) + "/lib"

require 'rubygems'
require 'bundler/setup'
require "bundler/gem_tasks"
require 'rdoc'
require 'rdoc/markup'
require 'rdoc/markup/formatter'
require 'rdoc/markup/to_ansi'

require 'fileutils'
require 'flare/tools'

Dir['tasks/**/*.rake'].each { |t| load t }

task :default => [:test]

task :manual do
  h = RDoc::Markup::ToAnsi.new
  rdoc = File.read("README.txt")
  puts h.convert(rdoc)
end

task :test do
  sh "(cd test && rake)"
end

task :stress_test do
  sh "(cd test && rake stress)"
end

task :clean do
  sh "(cd test && rake clean)"
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

task :cleanall => [:clean] do
end


