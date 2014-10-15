#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../../lib"

require 'test/unit'
require 'flare/tools/cluster'

class ClusterTest < Test::Unit::TestCase
  def setup
    data = [
            ["host1:12121", {"partition"=>"-1", "port"=>"12121", "thread_type"=>"17", "role"=>"proxy", "balance"=>"0", "state"=>"down"}],
            ["host2:12121", {"partition"=>"0", "port"=>"12121", "thread_type"=>"16", "role"=>"master", "balance"=>"4", "state"=>"active"}],
            ["host2:12122", {"partition"=>"0", "port"=>"12121", "thread_type"=>"16", "role"=>"slave", "balance"=>"4", "state"=>"active"}],
            ["host3:12121", {"partition"=>"0", "port"=>"12121", "thread_type"=>"18", "role"=>"slave", "balance"=>"100", "state"=>"prepare"}],
            ["host4:12121", {"partition"=>"1", "port"=>"12121", "thread_type"=>"18", "role"=>"master", "balance"=>"1", "state"=>"ready"}],
           ]
    @cluster = Flare::Tools::Cluster.new('127.0.0.1', 12120, data)
    @expected = data
  end

  def teardown
  end

  def test_cluster_simple1
    assert_equal(nil, @cluster.node_stat("xxx:12121"))
    assert_equal("host2:12121", @cluster.master_in_partition(0))
    assert_equal(["host2:12122", "host3:12121"].sort, @cluster.slaves_in_partition(0).sort)
  end

  def test_cluster_reconstructable1
    assert_equal(true, @cluster.reconstructable?("host2:12121"))
    assert_equal(false, @cluster.safely_reconstructable?("host2:12121"))
  end

  def test_cluster_stat1
    n1 = @cluster.node_stat("host1:12121")
    assert_equal(-1, n1.partition)
    assert_equal(17, n1.thread_type)
    assert_equal(true, n1.proxy?)
    assert_equal(0, n1.balance)
    assert_equal(true, n1.down?)

    n2 = @cluster.node_stat("host2:12121")
    assert_equal(0, n2.partition)
    assert_equal(16, n2.thread_type)
    assert_equal(true, n2.master?)
    assert_equal(4, n2.balance)
    assert_equal(true, n2.active?)

    n3 = @cluster.node_stat("host2:12122")
    assert_equal(0, n3.partition)
    assert_equal(16, n3.thread_type)
    assert_equal(true, n3.slave?)
    assert_equal(4, n3.balance)
    assert_equal(true, n3.active?)

    n4 = @cluster.node_stat("host3:12121")
    assert_equal(0, n4.partition)
    assert_equal(18, n4.thread_type)
    assert_equal(true, n4.slave?)
    assert_equal(100, n4.balance)
    assert_equal(true, n4.prepare?)

    n5 = @cluster.node_stat("host4:12121")
    assert_equal(1, n5.partition)
    assert_equal(18, n5.thread_type)
    assert_equal(true, n5.master?)
    assert_equal(1, n5.balance)
    assert_equal(true, n5.ready?)
  end

  def test_cluster_stat2
    @expected.each do |i|
      begin
        nodekey, data = i
        n = @cluster.node_stat(nodekey)
        assert_equal(data['partition'].to_i, n.partition)
        assert_equal(data['thread_type'].to_i, n.thread_type)
        assert_equal(data['role'] == 'proxy', n.proxy?)
        assert_equal(data['role'] == 'master', n.master?)
        assert_equal(data['role'] == 'slave', n.slave?)
        assert_equal(data['balance'].to_i, n.balance)
        assert_equal(data['state'] == 'down', n.down?)
        assert_equal(data['state'] == 'prepare', n.prepare?)
        assert_equal(data['state'] == 'ready', n.ready?)
        assert_equal(data['state'] == 'active', n.active?)
      rescue => e
        p i
        raise e
      end
    end
  end

end

