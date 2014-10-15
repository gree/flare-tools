#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools/common.rb'

class ToolsTest < Test::Unit::TestCase
  include Flare::Tools::Common

  def setup
    
  end

  def test_nodekey_of1
    expected = "hostname:12345"
    assert_equal(expected, nodekey_of("hostname:12345"))
    assert_equal(nil, nodekey_of("hostname:12345x"))
    assert_equal(expected, nodekey_of("hostname", "12345"))
    assert_equal(expected, nodekey_of(["hostname", "12345"]))
    assert_equal(nil, nodekey_of(["hostname"], ["12345"]))
  end

end
