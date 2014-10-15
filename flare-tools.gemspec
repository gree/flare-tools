# coding: utf-8
lib = File.dirname(__FILE__) + '/lib'
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flare/tools'

Gem::Specification.new do |spec|
  spec.name          = "flare-tools"
  spec.version       = Flare::Tools::VERSION
  spec.authors       = ["kikehara", "Yuya YAGUCHI"]
  spec.email         = ["kiyoshi.ikehara@gree.net", "yuya.yaguchi@gree.net"]
  spec.summary       = "Management Tools for Flare"
  spec.description   = "Flare-tools is a collection of tools for Flare distributed key-value store."
  spec.homepage      = "http://github.com/gree/flare-tools"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'log4r', '>= 1.1.10'
  spec.add_dependency 'tokyocabinet', '>= 1.29'

  spec.add_development_dependency "bundler", ">= 1.6"
  spec.add_development_dependency "rake"
end
