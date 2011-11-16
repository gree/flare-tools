
$LOAD_PATH << File.dirname(__FILE__)+"/lib"

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
  self.developer 'kikehara', 'kiyoshi.ikehara@gree.co.jp'
  self.url = 'http://github.com/kgws/flare-tools'
  self.summary = "Management Tools for Flare"
  self.post_install_message = 'PostInstall.txt'
  self.description = "Flare-tools is a collection of tools for Flare KVS."
  self.readme_file = "README.rdoc"
  self.extra_deps         = [
  ]
end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }

task :default => [:spec, :features]

task :readme_to_text do
  h = RDoc::Markup::ToAnsi.new
  rdoc = File.read("README.rdoc")
  puts h.convert(rdoc)
end
