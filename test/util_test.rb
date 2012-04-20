#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/util/result.rb'
require 'flare/util/interruption'
require 'flare/util/key_resolver'

class UtilTest < Test::Unit::TestCase
  Result = Flare::Util::Result

  class InterruptionTestException < Exception
  end

  class Interruption
    include Flare::Util::Interruption
    def interrupt
      raise InterruptionTestException.new
    end
  end

  def setup
    
  end
  
  def test_result1
    assert_equal("OK", Result.string_of_result(Result::Ok))
    assert_equal(Result.result_of_string("OK"), Result::Ok)
  end

  def test_interruption1
    obj = Interruption.new
    assert_raise InterruptionTestException do
      Process.kill :INT, Process.pid
    end
  end

  def test_key_resolver1
    partition_size = 1024
    virtual = 4096
    krm = Flare::Util::KeyResolver::Modular.new({:partition_size => partition_size, :virtual => virtual, :hint => 1})
    (0...100).each do |p|
      (0...virtual).each do |v|
        assert_not_equal(-1, krm.map(p, v))
      end
    end
  end
end

