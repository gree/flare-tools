#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools'
require 'flare/test/daemon'
require 'flare/test/cluster'

class NodeTest < Test::Unit::TestCase
  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @node_servers = ['node1', 'node2', 'node3'].map {|name| @flare_cluster.create_node(name)}
    sleep 1 # XXX
    @flare_cluster.wait_for_ready
    @flare_cluster.prepare_master_and_slaves(@node_servers)
  end
  
  def test_dummy
  end

  def test_one_million_entry
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000000)
  end if ENV['FLARE_TOOLS_STRESS_TEST']

  def test_incr1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    Flare::Tools::Node.open(@flare_cluster.indexname, @flare_cluster.indexport, 10) do |s|
      node = @node_servers[1]
      Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
        n.set("key", "0")
        n.set("noreply", "0")
        (1...10).each do |i|
          assert_equal(i.to_s, n.incr("key", 1))
          n.incr("noreply", 1)
        end
        assert_equal(9.to_s, n.get("noreply"))
      end
    end
  end


end

