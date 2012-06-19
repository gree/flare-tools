# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'uri'
require 'flare/tools'
require 'flare/test/daemon'
require 'flare/test/node'

# 
module Flare
  module Test

    # == Description
    #
    class Cluster
      include Flare::Tools::Common
      include Flare::Tools::ZkUtil

      def initialize(name, option = {})
        if ENV.has_key?("FLARE_INDEX_DB") && !option.has_key?("index-db")
          option["index-db"] = ENV["FLARE_INDEX_DB"]
        end

        if option.has_key?("index-db")
          uri = URI.parse(option["index-db"])
          if uri.scheme == "zookeeper"
            z = ::Zookeeper.new("#{uri.host}:#{uri.port}")
            clear_nodemap z, uri.path
            z.close
          end
        end

        daemon = Daemon.instance
        @indexport = daemon.assign_port
        @workdir = Dir.pwd+"/work"
        @datadir = [@workdir, "#{name}.#{@indexport}"].join('/')
        @nodes = {}

        @indexname = "localhost"
        @index_pid = daemon.invoke_flarei(name, {
                                            'server-name' => @indexname,
                                            'server-port' => @indexport,
                                            'data-dir' => @datadir,
                                          }.merge(option))
        @flare_xml = [@datadir, "flare.xml"].join('/')
        sleep 1
      end

      def indexname
        @indexname
      end

      def indexport
        @indexport
      end
      
      def create_node(name, config = {}, executable = Daemon::Flared)
        daemon = Daemon.instance
        serverport = daemon.assign_port

        datadir = [@datadir, "#{name}.#{serverport}"].join('.')

        servername = "localhost"
        pid = daemon.invoke_flared(name, {
                                     'index-server-name' => @indexname,
                                     'index-server-port' => @indexport,
                                     'server-name' => servername,
                                     'server-port' => serverport,
                                     'data-dir' => datadir,
                                   }.merge(config), executable)
        hostname_port = "#{servername}:#{serverport}"
        node = @nodes[hostname_port] = Node.new(hostname_port, pid)
        node
      end
      
      def shutdown
        daemon = Daemon.instance
        daemon.shutdown
      end

      def nodes
        @nodes.values
      end

      def wait_for_ready
        Flare::Tools::IndexServer.open(indexname, indexport, 10) do |s|
          wait_for_servers(s)
        end        
      end

      def prepare_master_and_slaves(nodes, partition = 0)
        Flare::Tools::IndexServer.open(indexname, indexport, 10) do |s|
          slaves = nodes.dup
          master = slaves.shift
          
          # master
          s.set_role(master.hostname, master.port, 'master', 1, partition)
          wait_for_master_construction(s, "#{master.hostname}:#{master.port}", 10)
          s.set_state(master.hostname, master.port, 'active')
          
          # slave
          slaves.each do |n|
            s.set_role(n.hostname, n.port, 'slave', 1, partition)
            wait_for_slave_construction(s, "#{n.hostname}:#{n.port}", 10, true)
          end
        end
      end

      def prepare_data(node, prefix, count)
        Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
          fmt = "#{prefix}%010.10d"
          (0...count).each do |i|
            n.set(fmt % i, "All your base are belong to us.")
          end
        end
      end

      def clear_data(node)
        Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
          n.flush_all
        end
      end

      def exist?(node)
        return Flare::Tools::IndexServer.open(indexname, indexport, 10) do |s|
          nodes_stats = s.stats_nodes
          nodes_stats.has_key? node
        end
      end

      def index
        open(@flare_xml) do |f|
          f.read
        end
      end

    end
  end
end
