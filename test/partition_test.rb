#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

class Result
  def initialize(resultq)
    @resultq = resultq
  end

  def get
    @resultq.pop
  end

  def sync
    @resultq.pop
  end
end

class FlareClient
  def initialize(node)
    @queue = Queue.new
    @resultq = Queue.new
    @node = node
    @th = Thread.new do
      while item = @queue.pop
        case item[0]
        when :get
          value = @node.get(item[1])
          @resultq.push(value)
        when :set
          @node.set(item[1], item[2])
          @resultq.push(nil)
        when :quit 
          @node.quit
          break
        when :detach
          break
        else
          p item
        end
      end
    end
  end

  def get(key)
    @queue.push([:get, key.to_s])
    Result.new(@resultq)
  end

  def set(key, value)
    @queue.push([:set, key.to_s, value.to_s])
    Result.new(@resultq)
  end

  def quit
    @queue.push([:quit])
    @th.join
  end

  def detach
    @queue.push([:detach])
    @th.join
  end
end


class PartitionTest < Test::Unit::TestCase
  include Flare::Tools::Common
  include Subcommands

  S_OK = 0
  S_NG = 1
  
  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @node_servers = ['node1', 'node2', 'node3', 'node4', 'node5', 'node6'].map {|name|
      @flare_cluster.create_node(name)
    }
    sleep 1 # XXX
    @flare_cluster.wait_for_ready
    @config = {
      :command => 'dummy',
      :index_server_hostname => @flare_cluster.indexname,
      :index_server_port => @flare_cluster.indexport,
      :dry_run => false,
      :timeout => 10
    }
    @nodes = @node_servers.map do |node|
      Flare::Tools::Node.open(node.hostname, node.port, 10)
    end
  end

  def teardown
    @nodes.map {|n| n.close}
  end

  def test_dynamic_partition_creation1
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    @flare_cluster.prepare_data(@node_servers[0], "key", 10)
    master = FlareClient.new(@nodes[0])
    args = @node_servers[2...3].map{|n| "#{n.hostname}:#{n.port}:1:1"}
    assert_equal(S_OK, master(*args))
    list
    for i in 0..10
      r = master.set("k#{i}", "piyo")
      r.sync
      sleep 1
      master_items = @nodes[0].stats["curr_items"].to_i
      slave_items = @nodes[1].stats["curr_items"].to_i
      puts "master_items=#{master_items}, slave_items=#{slave_items}"
      assert_equal(master_items, slave_items)
    end
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, activate(*args))
    master.detach
  end

  def test_dynamic_partition_creation2
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    @flare_cluster.prepare_data(@node_servers[0], "key", 10)
    master = FlareClient.new(@nodes[0])
    args = @node_servers[2...3].map{|n| "#{n.hostname}:#{n.port}:1:1"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[3...4].map{|n| "#{n.hostname}:#{n.port}:0:1"}
    assert_equal(S_OK, slave(*args))
    list
    basesize = @nodes[0].stats["curr_items"].to_i
    size = 10
    for i in 0...size
      r = master.set("k#{i}", "piyo")
      r.sync
      sleep 1
      master_items = @nodes[0].stats["curr_items"].to_i
      slave_items = @nodes[1].stats["curr_items"].to_i
      preparing_master_items = @nodes[2].stats["curr_items"].to_i
      preparing_slave_items = @nodes[3].stats["curr_items"].to_i
      puts "master=#{master_items}, slaves=#{slave_items}, preparing_master=#{preparing_master_items}, preparing_slave=#{preparing_slave_items}"
      assert_equal(master_items, slave_items)
    end
    assert_equal(size+basesize, master_items)
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, activate(*args))
    master.detach
  end

  def test_dynamic_partition_creation3
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    master = FlareClient.new(@nodes[0])
    assert_equal(S_OK, master(*@node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}:1:1"}))
    assert_equal(S_OK, slave(*@node_servers[3..3].map{|n| "#{n.hostname}:#{n.port}:0:1"}))
    assert_equal(S_OK, activate(*@node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}"}))
    assert_equal(S_OK, master(*@node_servers[4..4].map{|n| "#{n.hostname}:#{n.port}:1:2"}))
    assert_equal(S_OK, slave(*@node_servers[5..5].map{|n| "#{n.hostname}:#{n.port}:0:2"}))
    list
    size = 10
    for i in 0...size
      r = master.set("k#{i}", "piyo")
      r.sync
      sleep 1
      items = @nodes.map {|n| n.stats["curr_items"].to_i}
      assert_equal(items[0], items[1])
      assert_equal(items[2], items[3])
      assert_equal(items[4], items[5])
    end
    assert_equal(size, items[0]+items[2])
    assert_equal(S_OK, activate(*@node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}"}))
    master.detach
  end

end
