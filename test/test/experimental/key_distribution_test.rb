#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'flare/util/key_resolver'
require 'flare/util/hash_function'
require 'shell'
require 'test/unit'

class KeyDistributionTest < Test::Unit::TestCase
  include Flare::Util::HashFunction

  def setup
    @resolver = Flare::Util::KeyResolver.new
  end

  def test_key_distribution1
    proxy_concurrency = 8
    partition_size = 4
    prefix = "test::key::distribution"
    bin = []
    (0...proxy_concurrency).each do |i|
      bin[i] = 0
    end
    (1..10000).each do |i|
      key = "#{prefix}::#{i}"
      hash_of_key = get_key_hash_value(key, :bitshift, 32)
      target_thread = hash_of_key % proxy_concurrency
      target_partition = @resolver.resolve(get_key_hash_value(key, :simple, 32), partition_size)
      if target_partition == 0
        bin[target_thread] += 1
      end
    end
    p bin
  end

end
