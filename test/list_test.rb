#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

class ListTest < Test::Unit::TestCase
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

  def push_and_get(npush, nget)
    list if defined? DEBUG
    key = "k"
    (0...10).each do |i|
      value = "v#{i}"
      npush.x_list_push(key, value)
      nget.x_list_get(key, i, i+1) do |v, k, f|
        assert_equal(key, k)
        assert_equal(value, v)
      end
    end
  end

  def test_push_and_get_mm
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    push_and_get(@nodes[0], @nodes[0])
  end

  def test_push_and_get_mp
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    push_and_get(@nodes[0], @nodes[2])
  end

  def push_and_shift(npush, nshift)
    list if defined? DEBUG
    key = "k"
    size = 1000
    (0...size).each do |i|
      value = "v#{i}"
      npush.x_list_push(key, "v#{i}")
    end
    (0...size).each do |i|
      value = "v#{i}"
      v = nshift.x_list_shift(key)
      assert_equal(value, v)
    end
  end

  def test_push_and_shift_mm
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    push_and_shift(@nodes[0], @nodes[0])
  end

  def test_push_and_shift_ms
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    push_and_shift(@nodes[0], @nodes[1])
  end

  def test_push_and_shift_sm
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    push_and_shift(@nodes[1], @nodes[0])
  end

  def test_push_and_shift_ss
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
    push_and_shift(@nodes[1], @nodes[1])
  end

end

