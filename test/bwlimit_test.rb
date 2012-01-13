#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/util/bwlimit'
require 'timeout'

class BwlimitTest < Test::Unit::TestCase
  Bwlimit = Flare::Util::Bwlimit
  
  def setup
    
  end

  def bps(s, scale)
    assert_equal(0, Bwlimit.bps("#{s}B"), "#{s}B")
    assert_equal(100*scale, Bwlimit.bps("100#{s}b"), "100#{s}b")
    assert_equal(100*scale*8, Bwlimit.bps("100#{s}B"), "100#{s}B")
    assert_equal(10000*scale, Bwlimit.bps("10000#{s}b"), "10000#{s}b")
    assert_equal(10000*scale*8, Bwlimit.bps("10000#{s}B"), "10000#{s}B")
  end

  def test_bps1
    bps("", 1)
    bps("k", 1024)
    bps("M", 1024*1024)
    bps("G", 1024*1024*1024)
  end

  def test_limit1
    duration = 5
    size = 100
    total = size*1024*duration
    bwlimit = Bwlimit.new("#{size}kB")
    bwlimit.start
    assert_nothing_raised {
      timeout(duration*1.5) {
        while bwlimit.sentbytes < total
          bwlimit.inc((1500*(rand+1)).to_i)
          bwlimit.wait
          # puts "#{bwlimit.speed} bps, #{bwlimit.sentbytes}/#{total} bytes"
        end
      }
    }
    bwlimit.history.each do |e|
      t, b = e[:time], e[:speed]
      puts "#{t}, #{b}"
    end
  end

end
