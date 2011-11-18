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
    sleep 1
    @node_servers = ['node1', 'node2', 'node3'].map {|name| @flare_cluster.create_node(name)}
    sleep 1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
  end
  
  def test_dummy
  end

  def test_one_million_entry
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000000)
  end if ENV['FLARE_TOOLS_STRESS_TEST']
end

