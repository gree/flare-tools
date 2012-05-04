#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../../../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/test/cluster'

class ProxyTest < Test::Unit::TestCase
  include Flare::Tools::Common

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
  end

  def teardown
    @flare_cluster.shutdown
  end

  def test_proxy1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    Flare::Tools::Node.open(@flare_cluster.indexname, @flare_cluster.indexport, 10) do |s|
      puts string_of_nodelist(s.stats_nodes)
      node = @node_servers[1]
      puts "throwing requests to #{node.hostname}:#{node.port}."
      Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
        value = lambda {|key| return "value of "+key }
        fmt = "key%010.10d"
        (0...10).each do |i|
          n.set(fmt % i, value.call(fmt % i))
        end
        (0...10).each do |i|
          assert_equal(value.call(fmt % i), n.get(fmt % i))
        end
        sleep 1
      end
      puts string_of_nodelist(s.stats_nodes)
    end
  end

end
