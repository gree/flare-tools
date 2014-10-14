#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../../../lib")

require 'rubygems'
gem 'test-unit'
require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

class CliTest < Test::Unit::TestCase
  include Flare::Tools::Common
  include Subcommands

  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @node_servers = ['node1', 'node2', 'node3'].map {|name| @flare_cluster.create_node(name)}
    sleep 1 # XXX
    @flare_cluster.wait_for_ready

    @config = {
      :command => 'dummy',
      :dry_run => false,
      :timeout => 10
    }
    @index_server_hostname = @flare_cluster.indexname
    @index_server_port = @flare_cluster.indexport
  end

  def teardown
    @flare_cluster.shutdown
  end

  def test_ping_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    for node in @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
      assert_equal(S_OK, ping(node))
    end
  end

  def test_ping_invalid_argument1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    for node in @node_servers.map{|n| "#{n.hostname}"}
      assert_equal(S_NG, ping(node))
    end
    for node in @node_servers.map{|n| ":#{n.port}"}
      assert_equal(S_NG, ping(node))
    end
    for node in @node_servers.map{|n| "#{n.hostname}:#{n.port}:1"}
      assert_equal(S_NG, ping(node))
    end
  end

  def test_ping_all_nodes1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, ping(*args))
  end

  def test_ping_without_daemon1
    @node_servers.each {|n| n.terminate}
    # sleep 1
    for node in @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
      assert_equal(S_NG, ping(node))
    end
  end
  
  def test_list_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    assert_equal(S_OK, list())
    assert_equal(S_OK, list('--numeric-hosts'))
  end

  def test_list
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    assert_equal(S_OK, list())
    assert_equal(S_OK, list('--numeric-hosts'))
  end

  def test_list_log_file1
    File.delete("list.log") if File.exist?("list.log")
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    Flare::Util::Logging.set_logger('list.log')
    assert_equal(S_OK, list())
    assert_equal(true, File.exist?("list.log"))
    File.delete("list.log") if File.exist?("list.log")
  end

  def test_stats_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    assert_equal(S_OK, stats())
    assert_equal(S_OK, stats('--qps', '--count=5'))
    assert_equal(S_OK, stats('--qps', '--wait=2', '--count=3'))
  end

  def test_down_all_nodes1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
  end

  def test_down_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers[0..1].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
  end

  def test_down_except_last_one1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
  end

  def test_slave_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    newbalance = 1
    args = targets.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}:0"}
    # sleep 3
    assert_equal(S_OK, slave(*args))
  end

  def test_slave_with_option_clean1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift # remove master
    args = targets.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    @flare_cluster.clear_data(@node_servers[0])
    newbalance = 1
    args = targets.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}:0"} << "--clean"
    # sleep 3
    assert_equal(S_OK, slave(*args))
    size = targets.map {|slave| slave.open { |n| n.stats['cur_items'].to_i } }
    assert_equal(0, size[0])
    assert_equal(0, size[1])
  end

  def test_balance_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    newbalance = 4
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}"}
    assert_equal(S_OK, balance(*args))
  end

  def test_balance_invalid_argument1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    newbalance = 4
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_NG, balance(*args))
  end

  def test_reconstruct_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, reconstruct(*args))
  end

  def test_reconstruct_invalid_argument1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers.map{|n| "#{n.hostname}"}
    assert_equal(S_NG, reconstruct(*args))
    args = @node_servers.map{|n| ":#{n.port}"}
    assert_equal(S_NG, reconstruct(*args))
  end

  def test_reconstruct_reconstructable1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers.dup[1..-1].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_NG, reconstruct(*args))
  end

  def test_reconstruct_unsafe1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup[2..-1]
    args = targets.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--safe"
    assert_equal(S_NG, reconstruct(*args))
  end

  def test_index_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 10)
    assert_equal(S_OK, index())
  end

  def remove_boostheader_and_version(s)
    lines = s.split("\n")
    h1 = lines.shift
    h2 = lines.shift
    lines.shift # XXX boost header
    lines.shift # XXX version
    lines.unshift(h2)
    lines.unshift(h1)
    lines.join("\n")
  end

  def test_index_output_ident1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 10)
    args = ["--output=flare.xml"]
    assert_equal(S_OK, index(*args))
    assert_equal(true, File.exist?("flare.xml"))
    flarexml = remove_boostheader_and_version(open("flare.xml").read)
    indexxml = remove_boostheader_and_version(@flare_cluster.index)
    assert_equal(indexxml, flarexml)
    File.delete("flare.xml")
  end

  def test_remove_simple_call1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    master = targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--connection-threshold=4"
    # sleep 3
    assert_equal(S_OK, remove(*args))
    assert_equal(false, @flare_cluster.exist?(args[0]))
    assert_equal(false, @flare_cluster.exist?(args[1]))
  end

  def test_remove_unremovable1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    master = targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--connection-threshold=4" << "--wait=3"
    assert_equal(S_OK, remove(*args))
    assert_equal(true, @flare_cluster.exist?(args[0]))
    assert_equal(true, @flare_cluster.exist?(args[1]))
  end

  def test_master_simple1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, activate(*args))
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}:1:1"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, activate(*args))
  end

  def test_master_activate1
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, down(*args))
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}"}
    assert_equal(S_OK, activate(*args))
    args = @node_servers[2..3].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--activate"
    assert_equal(S_OK, master(*args))
  end

  def test_dump1
    
  end

  def test_dumpkey1
    args = @node_servers[0..0].map{|n| "#{n.hostname}:#{n.port}:1:0"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[1..1].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--activate"
    assert_equal(S_OK, master(*args))
    args = @node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}:1:2"} << "--activate"
    assert_equal(S_OK, master(*args))
    @flare_cluster.prepare_data(@node_servers[0], "key", 10000)
    args = @node_servers[0..2].map{|n| "#{n.hostname}:#{n.port}"} << "--bwlimit=800k" << "--output=keys.txt"
    assert_equal(S_OK, dumpkey(*args))
    File.delete("keys.txt") if File.exist?("keys.txt")
  end

  def test_dumpkey2
    args = @node_servers[0..0].map{|n| "#{n.hostname}:#{n.port}:1:0"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[1..1].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--activate"
    assert_equal(S_OK, master(*args))
    args = @node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}:1:2"} << "--activate"
    assert_equal(S_OK, master(*args))
    @flare_cluster.prepare_data(@node_servers[0], "key", 10000)
    args = ["--all"]
    args << "--bwlimit=800k" << "--output=keys.txt"
    assert_equal(S_OK, dumpkey(*args))
    File.delete("keys.txt") if File.exist?("keys.txt")
  end

  def test_verify1
    args = @node_servers[0..0].map{|n| "#{n.hostname}:#{n.port}:1:0"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[1..1].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--activate"
    assert_equal(S_OK, master(*args))
    args = @node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}:1:2"} << "--activate"
    assert_equal(S_OK, master(*args))
    kha = if Flare::Test::Daemon.instance.required_version? [1, 0, 15] then "crc32" else "simple" end
    args = ["--use-test-data", "--key-hash-algorithm=#{kha}"]
    assert_equal(S_OK, verify(*args))
  end

  def test_verify2
    args = @node_servers[0..0].map{|n| "#{n.hostname}:#{n.port}:1:0"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[1..1].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--activate"
    assert_equal(S_OK, master(*args))
    args = @node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}:1:2"} << "--activate"
    assert_equal(S_OK, master(*args))
    kha = unless Flare::Test::Daemon.instance.required_version? [1, 0, 15] then "crc32" else "simple" end
    args = ["--use-test-data", "--key-hash-algorithm=#{kha}"]
    assert_equal(S_NG, verify(*args))
  end

  def test_verify3
    args = @node_servers[0..0].map{|n| "#{n.hostname}:#{n.port}:1:0"}
    assert_equal(S_OK, master(*args))
    args = @node_servers[1..1].map{|n| "#{n.hostname}:#{n.port}:1:1"} << "--activate"
    assert_equal(S_OK, master(*args))
    args = @node_servers[2..2].map{|n| "#{n.hostname}:#{n.port}:1:2"} << "--activate"
    assert_equal(S_OK, master(*args))
    args = ["--use-test-data", "--meta"]
    assert_equal(S_OK, verify(*args))
  end

end
