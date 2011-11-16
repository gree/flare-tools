#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'

class CliTest < Test::Unit::TestCase
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

  def instantiate!(cls, args)
    opt = OptionParser.new
    subc = cls.new
    subc.setup(opt)
    opt.parse!(args)
    subc
  end
  
  def list(*args)
    subc = instantiate!(Flare::Tools::Cli::List, args)
    subc.execute(@config.merge({:command => 'list'}))
  end

  def test_list
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    assert_equal(0, list())
    assert_equal(0, list('--numeric-hosts'))
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
    assert_equal(0, stats())
    assert_equal(0, stats('--qps', '--count=5'))
    assert_equal(0, stats('--qps', '--wait=2', '--count=3'))
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
    assert_equal(0, down(*args))
  end

  def test_down_except_last_one
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets.shift
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(0, down(*args))
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
    assert_equal(0, down(*args))
    newbalance = 1
    args = targets.map{|n| "#{n.hostname}:#{n.port}:#{newbalance}:0"} << "--force"
    sleep 3
    assert_equal(0, slave(*args))
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
    assert_equal(0, balance(*args))
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
    assert_equal(0, reconstruct(*args))
    args = @node_servers.map{|n| "#{n.hostname}"} << "--force"
    assert_equal(1, reconstruct(*args))
    args = @node_servers.map{|n| ":#{n.port}"} << "--force"
    assert_equal(1, reconstruct(*args))
  end

  def test_reconstructable
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets = targets[1..-1]
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(0, down(*args))
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(1, reconstruct(*args))
  end

  def test_unsafe_reconstruct
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    @flare_cluster.prepare_data(@node_servers[0], "key", 1000)
    targets = @node_servers.dup
    targets = targets[2..-1]
    args = targets.map{|n| "#{n.hostname}:#{n.port}"} << "--force"
    assert_equal(0, down(*args))
    args = @node_servers.map{|n| "#{n.hostname}:#{n.port}"} << "--force" << "--safe"
    assert_equal(1, reconstruct(*args))
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
    assert_equal(0, index())
    assert_equal(0, index("--transitive"))
  end
end
