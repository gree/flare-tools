#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/util/logging.rb'

class LoggerTest < Test::Unit::TestCase
  include Flare::Util::Logging
  
  def test_call1
    assert_nothing_raised do
      info "info"
    end
    assert_nothing_raised do
      warn "warm"
    end
    assert_nothing_raised do
      error "error"
    end
    assert_nothing_raised do
      debug "debug"
    end
    assert_nothing_raised do
      fatal "fatal"
    end
  end

  def test_file1
    logfile = "work/logger_test_file1.log"
    assert_nothing_raised do
      Flare::Util::Logging.set_logger(logfile)
    end
    assert_nothing_raised do
      info "info"
      warn "warm"
      error "error"
      debug "debug"
      fatal "fatal"
    end
    assert_equal(true, File.exist?(logfile))
    File.delete logfile if File.exist?(logfile)
  end
  
end
