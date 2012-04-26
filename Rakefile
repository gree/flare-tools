
$LOAD_PATH.unshift File.dirname(__FILE__)+"/lib"

require 'rubygems'
gem 'hoe', '>= 2.1.0'
require 'hoe'
gem 'rdoc'
require 'rdoc'
require 'rdoc/markup'
require 'rdoc/markup/formatter'
require 'rdoc/markup/to_ansi'

require 'fileutils'
require 'flare/tools'

Hoe.plugin :newgem

$hoe = Hoe.spec 'flare-tools' do
  self.version = Flare::Tools::VERSION
  self.developer 'kikehara', 'kiyoshi.ikehara@gree.net'
  self.urls = ['http://github.com/gree/flare-tools']
  self.summary = "Management Tools for Flare"
  self.post_install_message = 'PostInstall.txt'
  self.description = "Flare-tools is a collection of tools for Flare distributed key-value store."
  self.readme_file = "README.txt"
  self.extra_deps = [['log4r', '>= 1.1.4']]
  self.rubyforge_name = 'flare-tools'
  self.extra_rdoc_files = []
end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }

task :default => [:spec, :features]

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

task :manifest_post do
  sh "grep -v '^debian' Manifest.txt| grep -v '^test' | grep -v '#\$' > Manifest.tmp"
  sh "mv Manifest.tmp Manifest.txt"
end

task :install => [:manifest, :manifest_post, :install_gem]

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


