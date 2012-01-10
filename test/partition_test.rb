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
        end
      end
    end
  end

  def get(key)
    @queue.push([:get, key.to_s])
    Result.new(@queue)
  end

  def set(key, value)
    @queue.push([:get, key.to_s, value.to_s])
    Result.new(@queue)
  end

  def quit
    @queue.push(:quit)
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
    @node_servers = ['node1', 'node2', 'node3', 'node4', 'node5'].map {|name|
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
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    master = FlareClient.new(@nodes[0])
    args = @node_servers[2...3].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--force"
    assert_equal(S_OK, master(*args))
    for i in 0..10
      r = master.set("k#{i}", "piyo")
      r.sync
      sleep 1
      master_items = @nodes[0].stats["curr_items"].to_i
      slave_items = @nodes[1].stats["curr_items"].to_i
      puts "master_items=#{master_items}, slave_items=#{slave_items}"
      assert_equal(master_items, slave_items)
    end
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, activate(*args))
    master.quit
  end

  def test_dynamic_partition_creation2
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    master = FlareClient.new(@nodes[0])
    args = @node_servers[2...3].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--force"
    assert_equal(S_OK, master(*args))
    args = @node_servers[3...4].map{|n| "#{n.hostname}:#{n.port}:0:1"} << "--force"
    assert_equal(S_OK, slave(*args))
    for i in 0..10
      r = master.set("k#{i}", "piyo")
      r.sync
      sleep 1
      master_items = @nodes[0].stats["curr_items"].to_i
      slave_items = @nodes[1].stats["curr_items"].to_i
      puts "master_items=#{master_items}, slave_items=#{slave_items}"
      assert_equal(master_items, slave_items)
    end
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, activate(*args))
    master.quit
  end

end
