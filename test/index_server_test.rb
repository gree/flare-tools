#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools.rb'
require 'flare/test/daemon'
require 'flare/test/cluster'

class IndexServerTest < Test::Unit::TestCase
  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1
    @node_servers = ['node1', 'node2', 'node3'].map {|name| @flare_cluster.create_node(name)}
    sleep 1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
  end
  
  def test_index_cluster_info
    hostname = @flare_cluster.indexname
    port = @flare_cluster.indexport
    stats = Flare::Tools::IndexServer.new(hostname, port, 10)
    nodes = stats.stats_nodes
    cluster = Flare::Tools::Cluster.new(hostname, port, nodes)
    assert_equal(cluster.size, @node_servers.size)
  end
  
end

