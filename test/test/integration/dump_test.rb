#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../lib")

require 'rubygems'
gem 'test-unit'
require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

class DumpTest < Test::Unit::TestCase
  include Flare::Tools::Common
  include Subcommands

  def setup
    File.delete("src.tch") if File.exist?("src.tch")
  end

  def teardown
    File.delete("src.tch") if File.exist?("src.tch")
  end

  def prepare cluster, partitions, ranges
    sleep 1 # XXX
    nodes = (1..6).map {|n| cluster.create_node("node#{n}")}
    sleep 1 # XXX
    cluster.wait_for_ready
    partitions.each do |p|
      cluster.prepare_master_and_slaves(nodes.values_at(*ranges[p]), p)
    end
    nodes
  end

  def dump_and_restore(range, prefixes, extra_dump_options, extra_restore_options, &check)
    # prepare
    ranges = [[0..1], [2..3], [4..5]]
    src_cluster = Flare::Test::Cluster.new('src')
    puts "preparing src"
    src_nodes = prepare(src_cluster, [0], ranges)
    puts "storing"
    range.each do |i|
      src_nodes[0].open do |n|
        prefixes.each do |prefix|
          n.set("#{prefix}::#{i}", "data")
        end
      end
    end
    src_nodes = prepare(src_cluster, [1, 2], ranges)
    puts "preparing dest"
    dest_cluster = Flare::Test::Cluster.new('dest')
    dest_nodes = prepare(dest_cluster, [0, 1, 2], ranges)

    puts "dumping"
    @config = {
      :index_server_hostname => src_cluster.indexname,
      :index_server_port => src_cluster.indexport,
      :timeout => 10
    }
    args = %w(--format=tch --output=src.tch)
    args.concat extra_dump_options
    assert_equal(S_OK, dump(*args))

    @config = {
      :index_server_hostname => dest_cluster.indexname,
      :index_server_port => dest_cluster.indexport,
      :timeout => 10
    }
    n = dest_nodes[0]
    args = %w(--format=tch --input=src.tch)
    args.concat extra_restore_options
    args << "#{n.hostname}:#{n.port}"
    assert_equal(S_OK, restore(*args))

    # check
    restored = [0, 2, 4].inject(0) do |r,i|
      dest_nodes[i].open do |n|
        r+n.stats["curr_items"].to_i
      end
    end
    check.call(restored)

    # destroy
    src_cluster.shutdown
    dest_cluster.shutdown
  end

  def test_dump_and_restore1
    dump_and_restore (0...100), ["prefix", "xiferp", "pre"], %w(--all), %w(--include=^prefix) do |restored|
      assert_equal(100, restored)
    end
  end

  def test_dump_and_restore2
    dump_and_restore (0...100), ["prefix", "xiferp", "pre"], %w(--all), %w(--prefix-include=prefix) do |restored|
      assert_equal(100, restored)
    end
  end

  def test_dump_and_restore3
    dump_and_restore (0...100), ["prefix", "xiferp", "pre"], %w(--all --raw), %w(--prefix-include=prefix) do |restored|
      assert_equal(100, restored)
    end
  end

end
