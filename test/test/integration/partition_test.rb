#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../../../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

begin
  require 'progressbar'
rescue LoadError => e
end

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
    @node_servers = ['node1', 'node2', 'node3', 'node4', 'node5', 'node6', 'node7'].map {|name|
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
    @nodes = @node_servers.map {|node| node.open}
    @wait = 0.005
  end

  def teardown
    @nodes.map {|n| n.close}
    @flare_cluster.shutdown
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
      sleep @wait
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
      sleep @wait
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

  def dynamic_partition_creation3(ntarget)
    p, m0, s0, m1, s1, m2, s2 = 0, 1, 2, 3, 4, 5, 6
    @flare_cluster.prepare_master_and_slaves(@node_servers[m0..s0])
    target = FlareClient.new(ntarget)
    assert_equal(S_OK, master(*@node_servers[m1..m1].map{|n| "#{n.hostname}:#{n.port}:1:1"}))
    assert_equal(S_OK, slave(*@node_servers[s1..s1].map{|n| "#{n.hostname}:#{n.port}:1:1"}))
    assert_equal(S_OK, activate(*@node_servers[m1..m1].map{|n| "#{n.hostname}:#{n.port}"}))
    assert_equal(S_OK, master(*@node_servers[m2..m2].map{|n| "#{n.hostname}:#{n.port}:1:2"}))
    assert_equal(S_OK, slave(*@node_servers[s2..s2].map{|n| "#{n.hostname}:#{n.port}:1:2"}))
    list
    size = 10
    for i in 0...size
      r = target.set("k#{i}", "piyo")
      r.sync
      sleep @wait
      items = @nodes.map {|n| n.stats["curr_items"].to_i}
      assert_equal(items[m0], items[s0])
      assert_equal(items[m1], items[s1])
      assert_equal(items[m2], items[s2])
    end
    assert_equal(size, items[m0]+items[m1])
    assert_equal(S_OK, activate(*@node_servers[m2..m2].map{|n| "#{n.hostname}:#{n.port}"}))
    for i in 0...size
      r = target.set("k#{i}", "piyo")
      r.sync
      sleep @wait
      items = @nodes.map {|n| n.stats["curr_items"].to_i}
      assert_equal(items[m0], items[s0])
      assert_equal(items[m1], items[s1])
      assert_equal(items[m2], items[s2])
    end
    target.detach
  end

  def self.deftest_all(name)
    syms = ["p", "m0", "s0", "m1", "s1", "m2", "s2"]
    for i in (0...syms.size)
      self.class_eval %{
        def test_#{name.to_s}_#{syms[i]}
          #{name.to_s}(@nodes[#{i}])
        end
      }
    end
  end

  deftest_all :dynamic_partition_creation3

  def test_dynamic_partition_creation4
    p, m0, s0, m1, s1, m2, s2 = 0, 1, 2, 3, 4, 5, 6
    @flare_cluster.prepare_master_and_slaves(@node_servers[m0..s0])
    assert_equal(S_OK, master(*@node_servers[m1..m1].map{|n| "#{n.hostname}:#{n.port}:1:1"}))
    assert_equal(S_OK, slave(*@node_servers[s1..s1].map{|n| "#{n.hostname}:#{n.port}:1:1"}))
    assert_equal(S_OK, activate(*@node_servers[m1..m1].map{|n| "#{n.hostname}:#{n.port}"}))
    assert_equal(S_OK, master(*@node_servers[m2..m2].map{|n| "#{n.hostname}:#{n.port}:1:2"}))
    assert_equal(S_OK, slave(*@node_servers[s2..s2].map{|n| "#{n.hostname}:#{n.port}:1:2"}))
    targets = @nodes.map {|n| FlareClient.new(n)}
    list
    size = 1000
    pbar = ProgressBar.new('test_dynamic_partition_creation4', size, $stderr) if defined? ProgressBar
    for i in 0...size
      r = targets[rand(targets.size)].set("k#{i}", "piyo")
      r.sync
      sleep @wait
      items = @nodes.map {|n| n.stats["curr_items"].to_i}
      assert_equal(items[m0], items[s0])
      assert_equal(items[m1], items[s1])
      assert_equal(items[m2], items[s2])
      if defined? ProgressBar
        pbar.inc
      end
      assert_equal(S_OK, activate(*@node_servers[m2..m2].map{|n| "#{n.hostname}:#{n.port}"})) if i == size/2
    end
    targets.each {|c| c.detach}
  end

end
