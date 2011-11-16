#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools.rb'
require 'flare/test/daemon'
require 'flare/test/cluster'

class StatsTest < Test::Unit::TestCase
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
    stats = Flare::Tools::Stats.new(hostname, port, 10)
    cluster = Flare::Tools::Cluster.new(hostname, port, stats.stats_nodes)
    assert_equal(cluster.size, @node_servers.size)
  end
  
  def test_node_cluster_info
    clusters = @node_servers.map { |node_server|
      hostname = node_server.hostname
      port = node_server.port
      stats = Flare::Tools::Stats.new(hostname, port, 10)
      nodes = stats.stats_nodes
      Flare::Tools::Cluster.new(hostname, port, nodes)
    }
    clusters.each do |cluster|
      assert_equal(clusters[0].size, cluster.size)
    end
  end
end

