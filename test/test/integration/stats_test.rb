#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

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

  def teardown
    @flare_cluster.shutdown
  end
  
  def test_index_cluster_info
    hostname = @flare_cluster.indexname
    port = @flare_cluster.indexport
    stats = Flare::Tools::Stats.new(hostname, port, 10)
    cluster = Flare::Tools::Cluster.new(hostname, port, stats.stats_nodes)
    assert_equal(cluster.size, @node_servers.size)
  end
  
  def test_node_cluster_info
    clusters = @node_servers.map {|node_server|
      hostname = node_server.hostname
      port = node_server.port
      stats = Flare::Tools::Stats.new(hostname, port, 10)
      nodes = stats.stats_nodes
      Flare::Tools::Cluster.new(hostname, port, nodes)
    }
    clusters.each {|cluster|
      assert_equal(clusters[0].size, cluster.size)
    }
  end

  def test_client_stats_threads
    @node_servers.each {|node_server|
      hostname = node_server.hostname
      port = node_server.port
      stats = Flare::Tools::Stats.new(hostname, port, 10)
      r = stats.stats_threads
      if stats.required_version?([1,0,10])
        assert_not_equal({}, r)
      else
        assert_equal({}, r)
      end
    }
  end

  def test_version
    @node_servers.each {|node_server|
      hostname = node_server.hostname
      port = node_server.port
      stats = Flare::Tools::Stats.new(hostname, port, 10)
      assert_equal(false, stats.required_version?([100,0,0]))
      assert_equal(true, stats.required_version?([1,0,0]))
      assert_equal(false, stats.required_version?([3,4,6], [3,4,5]))
      assert_equal(true, stats.required_version?([3,4,5], [3,4,5]))
      assert_equal(true, stats.required_version?([3,4,4], [3,4,5]))
      assert_equal(false, stats.required_version?([3,5,5], [3,4,5]))
      assert_equal(true, stats.required_version?([3,4,5], [3,4,5]))
      assert_equal(true, stats.required_version?([3,3,5], [3,4,5]))
      assert_equal(false, stats.required_version?([4,4,6], [3,4,5]))
      assert_equal(true, stats.required_version?([3,4,5], [3,4,5]))
      assert_equal(true, stats.required_version?([2,4,4], [3,4,5]))
    }
  end
end

