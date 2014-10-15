#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../../../lib"

require 'test/unit'
require 'flare/tools'
require 'flare/test/cluster'

ENV['FLARE_INDEX_SERVER'] = nil

class FlareAdminTest < Test::Unit::TestCase
  Admin = "./bin/flare-admin"
  S_OK = 0
  S_NG = 1

  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @datanodes = ['node1', 'node2', 'node3'].map {|name| @flare_cluster.create_node(name)}
    sleep 1 # XXX
    @flare_cluster.wait_for_ready
    @indexname = @flare_cluster.indexname
    @indexport = @flare_cluster.indexport
    @opt_index = "--index-server=#{@indexname}:#{@indexport}"
  end

  def teardown
    @flare_cluster.shutdown
  end

  def flare_admin_with_yes arg
    cmd = "yes | ruby #{Admin} #{arg}"
    puts "> #{cmd}"
    puts `#{cmd}`
    $?.exitstatus
  end

  def flare_admin arg
    cmd = "ruby #{Admin} #{arg}"
    puts "> #{cmd}"
    puts `#{cmd}`
    $?.exitstatus
  end

  def test_subc_simple1
    flare_admin "help"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin ""
    assert_equal(S_NG, $?.exitstatus)
  end

  def test_common_option_long1
    flare_admin "list --index-server"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --index-server-port"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --index-server --index-server-port"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname} --index-server-port=#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname}:#{@indexport} --index-server-port=#{@indexport}"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --log-file"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --log-file=/"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --log-file=''"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --log-file=''"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin_with_yes "down #{@opt_index} --dry-run #{@datanodes[0].hostname}:#{@datanodes[0].port}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list #{@opt_index} --timeout=20"
    assert_equal(S_OK, $?.exitstatus)
  end

  def test_common_option_short1
    flare_admin "list"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list -i"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list -i -p"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list -p"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list -i #{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list -i #{@indexname} -p #{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list -i #{@indexname}:#{@indexport} -p #{@indexport}"
    assert_equal(S_NG, $?.exitstatus)
  end

  def test_list_simple1
    flare_admin "list"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname}:#{@indexport} --index-server-port=#{@indexport}"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list #{@opt_index} --numeric-hosts"
    assert_equal(S_OK, $?.exitstatus)
  end

  def test_log_file1
    filename = "logfile.log"
    exist = File.exist?(filename)
    flare_admin "list --log-file=#{filename}"
    assert_equal(S_NG, $?.exitstatus)
    exist = File.exist?(filename)
    assert_equal(true, exist)
  ensure
    File.delete(filename) if exist
  end

  def test_ping_simple1
    flare_admin "ping"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "ping #{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "ping #{@datanodes[0].hostname}:#{@datanodes[0].port}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "ping #{@datanodes[0].hostname}:23"
    assert_equal(S_NG, $?.exitstatus)
  end

  def test_ping_wait1
    flare_admin "ping --wait"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "ping --wait #{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "ping --wait #{@datanodes[0].hostname}:#{@datanodes[0].port}"
    assert_equal(S_OK, $?.exitstatus)
  end

  def test_thread_simple1
    flare_admin "threads"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "threads --index-server=#{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "threads #{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "threads #{@datanodes[0].hostname}:#{@datanodes[0].port}"
    assert_equal(S_OK, $?.exitstatus)
  end

  def test_master_simple1
    h = @datanodes[0].hostname
    p = @datanodes[0].port
    flare_admin_with_yes "master --index-server=#{@indexname}:#{@indexport} #{h}:#{p}:1:0"
    assert_equal(S_OK, $?.exitstatus)
  end

  def test_reconstruct_simple1
    h = @datanodes[0].hostname
    p = @datanodes[0].port
    flare_admin_with_yes "master --index-server=#{@indexname}:#{@indexport} #{h}:#{p}:1:0"
    assert_equal(S_OK, $?.exitstatus)
    h = @datanodes[1].hostname
    p = @datanodes[1].port
    flare_admin_with_yes "slave --index-server=#{@indexname}:#{@indexport} #{h}:#{p}:1:0"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin_with_yes "reconstruct --index-server=#{@indexname}:#{@indexport} --all"
    assert_equal(S_OK, $?.exitstatus)
  end

  def test_index_servers_env1
    ENV["FLARE_INDEX_SERVERS"] = "clustername:#{@indexname}:#{@indexport}"
    flare_admin "list"
    assert_equal(S_NG, $?.exitstatus)
    h = @datanodes[0].hostname
    p = @datanodes[0].port
    flare_admin_with_yes "master #{h}:#{p}:1:0"
    assert_equal(S_OK, $?.exitstatus)
  ensure
    ENV["FLARE_INDEX_SERVERS"] = nil
  end

  def test_index_servers_env2
    ENV["FLARE_INDEX_SERVERS"] = "clustername:#{@indexname}:#{@indexport}"
    flare_admin "list"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --cluster=clustername"
    assert_equal(S_OK, $?.exitstatus)
  ensure
    ENV["FLARE_INDEX_SERVERS"] = nil
  end

end

