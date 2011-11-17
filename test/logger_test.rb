#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/util/logger.rb'

class LoggerTest < Test::Unit::TestCase
  include Flare::Util::Logging
  
  def test_call1
    info "info"
    warn "warm"
    error "error"
    debug "debug"
  end
end


