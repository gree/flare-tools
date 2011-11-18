#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/util/result.rb'

class UtilTest < Test::Unit::TestCase
  class Result
    include Flare::Util::Result
  end

  def setup
  end
  
  def test_result1
    assert_equal("OK", Result.new.string_of_result(Result::Ok))
    assert_equal(Result.new.result_of_string("OK"), Result::Ok)
  end
end

