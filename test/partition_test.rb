#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

class PartitionTest < Test::Unit::TestCase
  include Flare::Tools::Common
  include Subcommands

  S_OK = 0
  S_NG = 1
  
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
    @nodes = @node_servers.map do |node|
      Flare::Tools::Node.open(node.hostname, node.port, 10)
    end
  end

  def teardown
    @nodes.map {|n| n.close}
  end

  def master(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Master.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'master'}), *args)
  end

  def test_dynamic_partition_creation1
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    queue = Queue.new
    th = Thread.new do
      while item = queue.pop
        @nodes[0].set("hoge#{item}", "piyo")
      end
    end
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--force"
    assert_equal(S_OK, master(*args))
    for i in 0..10
      queue.push "#{i}"
      sleep 1
      master_items = @nodes[0].stats["curr_items"].to_i
      slave_items = @nodes[1].stats["curr_items"].to_i
      puts "master_items=#{master_items}, slave_items=#{slave_items}"
      assert_equal(master_items, slave_items)
    end
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, activate(*args))
    queue.push false
    th.join
  end

end
