#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'

class CliTest < Test::Unit::TestCase
  include Flare::Tools::Common

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
  end

  def instantiate(cls, args)
    opt = OptionParser.new
    subc = cls.new
    subc.setup(opt)
    opt.parse!(args)
    subc
  end

  def ping(*args)
    subc = instantiate(Flare::Tools::Cli::Ping, args)
    subc.execute(@config.merge({:command => 'ping'}), *args)
  end

  def test_ping_without_daemon
    @node_servers.each {|n| n.terminate}
    sleep 1
    for node in @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
      assert_equal(S_NG, ping(node))
    end
  end

  def test_ping
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    for node in @node_servers.map{|n| "#{n.hostname}:#{n.port}"}
      assert_equal(S_OK, ping(node))
    end
  end
  
  def list(*args)
    subc = instantiate(Flare::Tools::Cli::List, args)
    subc.execute(@config.merge({:command => 'list'}))
  end
  
  def test_list
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    assert_equal(S_OK, list())
    assert_equal(S_OK, list('--numeric-hosts'))
  end

  def stats(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Stats.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'stats'}), *args)
  end

  def test_stats
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    assert_equal(S_OK, stats())
    assert_equal(S_OK, stats('--qps', '--count=5'))
    assert_equal(S_OK, stats('--qps', '--wait=2', '--count=3'))
  end

  def down(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Down.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'down'}), *args)
  end

  def test_down_all
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
  end

  def test_down_except_last_one
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
  end

  def slave(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Slave.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'slave'}), *args)
  end

  def test_slave
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
    newbalance = 1
    args = targets.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}:0"} << "--force"
    sleep 3
    assert_equal(S_OK, slave(*args))
  end

  def test_slave_clean
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift # remove master
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
    @flare_cluster.clear_data(@node_servers[0])
    newbalance = 1
    args = targets.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}:0"} << "--force" << "--clean"
    sleep 3
    assert_equal(S_OK, slave(*args))
    size = targets.map {|slave| slave.open { |n| n.stats['cur_items'].to_i } }
    assert_equal(0, size[0])
    assert_equal(0, size[1])
  end

  def balance(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Balance.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'balance'}), *args)
  end

  def test_balance
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    newbalance = 4
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}"} << "--force"
    assert_equal(S_OK, balance(*args))
  end
  
  def reconstruct(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Reconstruct.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'reconstruct'}), *args)
  end

  def test_reconstruct
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, reconstruct(*args))
    args = @node_servers.map{|n| "#{n.hostname}"} << "--force"
    assert_equal(S_NG, reconstruct(*args))
    args = @node_servers.map{|n| ":#{n.port}"} << "--force"
    assert_equal(S_NG, reconstruct(*args))
  end

  def test_reconstruct_reconstructable
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets = targets[1..-1]
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_NG, reconstruct(*args))
  end

  def test_reconstruct_unsafe
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets = targets[2..-1]
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--force" << "--safe"
    assert_equal(S_NG, reconstruct(*args))
  end

  def index(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Index.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'index'}))
  end

  def test_index
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 10)
    assert_equal(S_OK, index())
  end

  def test_index_ident
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 10)
    args = ["--output=flare.xml"]
    assert_equal(S_OK, index(*args))
    assert_equal(true, File.exist?("flare.xml"))
    assert_equal(@flare_cluster.index, open("flare.xml").read)
    File.delete("flare.xml")
  end

  def remove(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Remove.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'remove'}), *args)
  end

  def test_remove
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    master = targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(S_OK, down(*args))
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force" << "--connection-threshold=4"
    sleep 3
    assert_equal(S_OK, remove(*args))
    assert_equal(false, @flare_cluster.exist?(args[0]))
    assert_equal(false, @flare_cluster.exist?(args[1]))
  end

  def test_remove_unremovable
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    master = targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force" << "--connection-threshold=4" << "--wait=3"
    assert_equal(S_OK, remove(*args))
    assert_equal(true, @flare_cluster.exist?(args[0]))
    assert_equal(true, @flare_cluster.exist?(args[1]))
  end

end
