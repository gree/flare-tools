#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../../../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/test/daemon'
require 'flare/test/cluster'
require 'subcommands'

class DumpExpiredTest < Test::Unit::TestCase
  include Flare::Tools::Common
  include Subcommands

  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @node_servers = ['node1', 'node2', 'node3'].map {|name| @flare_cluster.create_node(name)}
    sleep 1 # XXX
    @flare_cluster.wait_for_ready
    @config = {
      :command => 'dummy',
      :index_server_hostname => @flare_cluster.indexname,
      :index_server_port => @flare_cluster.indexport,
      :dry_run => false,
      :timeout => 10
    }
  end

  def teardown
    @flare_cluster.shutdown
  end

  def test_dump_expired
    efmt = "key%05.5d"
    mfmt = "exp%05.5d"
    statsth = Thread.new do
      stats('--count=40')
    end
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    master = @node_servers[0]
    m = Flare::Tools::Node.open(master.hostname, master.port, 10)
    (0...1000).each do |i|
      m.set(mfmt % i, "MORTAL", 0, 1)
    end
    sleep 3
    @node_servers[1..2].each do |node|
      dumpth = Thread.new do
        Flare::Tools::Node.open(node.hostname, node.port, 10) do |dn|
          puts "DUMP START."
          dn.dump(1000) do |data, key, flag, len, version, expire|
            if key =~ /exp.*/
              print " #{key}(#{expire})"
              assert_equal("MORTAL", data)
              assert_not_equal(0, expire)
            end
          end
          puts "DUMP DONE."
        end
      end
      Flare::Tools::Node.open(master.hostname, master.port, 10) do |n|
        puts "SET START."
        flag = 0
        expire = 3
        (0...1000).each do |i|
          m.set(efmt % i, "ETERNAL", 0, 0)
          n.set(mfmt % i, "MORTAL", flag, expire+rand(3))
          n.get(mfmt % (rand(i)))
        end
        puts "SET DONE."
      end
      dumpth.join
    end
    statsth.join
    puts "checking ..."
    stats
    items = @node_servers[1..2].map do |node|
      Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
        n.stats["curr_items"].to_i
      end
    end
    assert(items[0] >= items[1], "#{items[0]} < #{items[1]}")
    puts "dumping again..."
    sleep 8
    @node_servers[0..2].each do |node|
      Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
        n.dump
      end
    end
    puts "checking again ..."
    stats
    items = @node_servers[1..2].map do |node|
      Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
        n.stats["curr_items"].to_i
      end
    end
    assert(items[0] >= items[1], "#{items[0]} < #{items[1]}")
    m.close
  end
end

