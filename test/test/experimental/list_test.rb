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
    (0...100).each do |i|
      value = "v#{i}"
      npush.x_list_push(key, value)
      sleep 0.001
      count = 0
      nget.x_list_get(key, i, i+1) do |v, k, rel, abs, flag, len, version, expire|
        assert_equal(key, k)
        assert_equal(value, v)
        count += 1
      end
      assert_equal(1, count)
    end
  end

  def push_and_range_get(npush, nget)
    list if defined? DEBUG
    key = "k"
    size = 100
    range = (0...size)
    expected = range.map {|i| "v#{i}"}
    range.each do |i|
      npush.x_list_push(key, expected[i])
    end
    count = 0
    nget.x_list_get(key, 0, size) do |v, k, rel, abs, f|
      value = "v#{count}"
      assert_equal(key, k)
      assert_equal(value, v)
      count += 1
    end
    assert_equal(size, count)
  end

  def push_and_shift(npush, nshift)
    list if defined? DEBUG
    key = "k"
    range = (0...100)
    expected = range.map {|i| "v#{i}"}
    range.each do |i|
      npush.x_list_push(key, expected[i])
    end
    values = range.map {|i| nshift.x_list_shift(key)}
    assert_equal(expected, values)
  end

  def self.deftest_allpair(name)
    syms = ["m", "s", "p"]
    for i in (0...syms.size)
      for j in (0...syms.size)
        self.class_eval %{
          def test_#{name.to_s}_#{syms[i]}#{syms[j]}
            @flare_cluster.prepare_master_and_slaves(@node_servers[0..1])
            #{name.to_s}(@nodes[#{i}], @nodes[#{j}])
          end
        }
      end
    end
  end

  deftest_allpair :push_and_get
  deftest_allpair :push_and_range_get
  deftest_allpair :push_and_shift

end

