#!/usr/bin/ruby
# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools'
require 'flare/test/cluster'

ENV['FLARE_INDEX_SERVER'] = nil

class FlareAdminTest < Test::Unit::TestCase
  Admin = "../bin/flare-admin"
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
  end

  def teardown
    @flare_cluster.shutdown
  end

  def flare_admin_with_yes arg
    cmd = "yes | #{Admin} #{arg}"
    puts "> #{cmd}"
    puts `#{cmd}`
    $?.exitstatus
  end

  def flare_admin arg
    cmd = "#{Admin} #{arg}"
    puts "> #{cmd}"
    puts `#{cmd}`
    $?.exitstatus
  end

  def test_list_simple1
    flare_admin "list"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname}:#{@indexport}"
    assert_equal(S_OK, $?.exitstatus)
    flare_admin "list --index-server=#{@indexname}:#{@indexport} --index-server-port=#{@indexport}"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin "help"
    assert_equal(S_NG, $?.exitstatus)
    flare_admin ""
    assert_equal(S_NG, $?.exitstatus)
  end

  def test_master_simple1
    h = @datanodes[0].hostname
    p = @datanodes[0].port
    flare_admin_with_yes "master #{h}:#{p}:1:0"
  end

  def test_reconstruct_simple1
    h = @datanodes[0].hostname
    p = @datanodes[0].port
    flare_admin_with_yes "master #{h}:#{p}:1:0"
    h = @datanodes[1].hostname
    p = @datanodes[1].port
    flare_admin_with_yes "master #{h}:#{p}:1:0"
    flare_admin_with_yes "reconstruct --all"
  end

end

