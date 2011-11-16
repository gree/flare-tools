#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/test/cluster'
require 'flare/tools/index_server'
require 'flare/tools/common'

class DaemonTest < Test::Unit::TestCase
  include Flare::Tools::Common

  def test_cluster
    cluster = Flare::Test::Cluster.new('stats')
    nodes = ['node1', 'node2', 'node3'].map {|name| cluster.create_node(name)}
    sleep 1
    cluster.prepare_master_and_slaves(nodes)
    
    nodes[0].open do |node|
      (0..10).each do |x|
        k = "key%05.5d" % x
        v = "foo"
        node.set(k, v)
        node.get(k)
      end
    end
  end
end

