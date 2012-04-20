#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift(File.dirname(__FILE__)+"/../lib")

require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'
require 'subcommands'

class CacheTest < Test::Unit::TestCase
  include Flare::Tools::Common
  include Subcommands

  S_OK = 0
  S_NG = 1

  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @node_servers = ['localmaster1', 'localproxy1', 'remoteproxy1'].map {|name|
      @flare_cluster.create_node(name, { 'proxy-cache-size' => 1000, 'proxy-cache-expire' => 60 }, "/usr/local/proxy_cache/bin/flared")
    }
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
    @localmaster1, @localproxy1, @remoteproxy1 = @nodes
  end
  
  def teardown
    @nodes.map {|n| n.close}
  end

  def test_proxy_gets_from_various_routes
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..0])
    key = "hoge"
    @localmaster1.set(key, "v1")
    value, version = @localmaster1.gets(key)
    assert_equal(1, version);
    assert_equal("v1", value);
    @localproxy1.set(key, "v2")
    value, version = @localmaster1.gets(key)
    assert_equal(2, version);
    assert_equal("v2", value);
    @remoteproxy1.set(key, "v3")
    value, version = @localmaster1.gets(key)
    assert_equal(3, version);
    assert_equal("v3", value);
  end

  def test_proxy_cas_to_master
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..0])
    key = "hoge"
    @localmaster1.set(key, "v1")
    value, version = @localmaster1.gets(key)
    assert_equal(1, version);
    @localmaster1.cas(key, "v2", version)
    value, version = @localmaster1.gets(key)
    assert_equal(2, version);
    @localproxy1.cas(key, "v3", version)
    value, version = @localproxy1.gets(key)
    assert_equal(3, version);
  end

  class Client
    def initialize(node)
      @node = node
    end
    
    def gets(*keys)
      @node.gets(*keys)
    end
    
    def cas(*keys)
      @node.cas(*keys)
    end
  end

  def test_proxy_gets_and_cas
    @flare_cluster.prepare_master_and_slaves(@node_servers[0..0])
    key = "hoge"

    @localmaster1.set(key, "initial")

    c0 = Client.new(@localmaster1)
    c1 = Client.new(@remoteproxy1)
    c2 = Client.new(@remoteproxy1)

    v1,v1version = c1.gets(key)
    v0,v0version = c0.gets(key)
    v2,v2version = c2.gets(key)
    
    r0 = c0.cas(key, "client0", v0version)
    r1 = c1.cas(key, "client1", v1version)
    r2 = c2.cas(key, "client2", v2version)

    assert_equal(true, r0)
    assert_equal(false, r1)
    assert_equal(false, r2)
  end
  
end

