#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH File.dirname(__FILE__)+"/../lib"

require 'flare/util/result.rb'

include Flare::Util::Result

p string_of_result(Ok)
p result_of_string("OK")

