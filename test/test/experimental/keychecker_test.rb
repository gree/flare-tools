#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'shell'
require 'test/unit'

Shell.verbose = false
Shell.def_system_command "kc", "../../bin/flare-keychecker"

class KeycheckerTest < Test::Unit::TestCase
  KeyTxt = "keychecker_test.key.txt"
  ResultCsv = "keychecker_test.result.csv"

  def setup
    @basedir = File.dirname(__FILE__)+"/work"
    @sh = Shell.new
    @sh.cd(@basedir)
    @sh.transact {
      unless exist? KeyTxt
        keys = (0...1000).inject([]) {|r,v| r << "prefix::#{v}"}
        echo(*keys) >> KeyTxt
      end
    }
  end

  def test_help1
    @sh.transact {
      kc("--help")
    }
  end

  def hash(type)
    @sh.transact {
      (cat(KeyTxt) | kc("--hash=#{type}")) > ResultCsv
    }
  end

  def test_hash1
    hash("simple")
    hash("bitshift")
    hash("crc32")
  end

  def delimiter(delimiter)
    @sh.transact {
      echo(*@keys) >> KeyTxt
      (cat(KeyTxt) | kc("--delimiter=#{delimiter}")) > ResultCsv
    }
  end

  def test_delimiter1
    delimiter("::")
  end

end

  

