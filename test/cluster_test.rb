#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools/cluster'

class ClusterTest < Test::Unit::TestCase
  def setup
    data = [
            ["host1:12121", {"partition"=>"-1", "port"=>"12121", "thread_type"=>"17", "role"=>"proxy", "balance"=>"0", "state"=>"active"}],
            ["host2:12121", {"partition"=>"0", "port"=>"12121", "thread_type"=>"16", "role"=>"master", "balance"=>"4", "state"=>"active"}],
            ["host2:12122", {"partition"=>"0", "port"=>"12121", "thread_type"=>"16", "role"=>"slave", "balance"=>"4", "state"=>"active"}],
            ["host3:12121", {"partition"=>"0", "port"=>"12121", "thread_type"=>"18", "role"=>"slave", "balance"=>"4", "state"=>"active"}],
           ]
    @cluster = Flare::Tools::Cluster.new('127.0.0.1', 12120, data)
  end
  def teardown
  end
  def test_other
    p @cluster.node_stat("ike:12121")
    p @cluster.master_in_partition(0)
    p @cluster.slaves_in_partition(0)
  end
  def test_reconstructable
    assert_equal(true, @cluster.reconstructable?("host2:12121"))
  end
end

