# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

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

      def initialize(name)
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
                                          })
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
          role = 'master'
          nodes.each do |n|
            s.set_role(n.hostname, n.port, role, 1, partition)
            role = 'slave'
          end
          role = 'master'
          nodes.each do |n|
            wait_for_slave_construction(s, "#{n.hostname}:#{n.port}", 10, true) if role == 'slave'
            s.set_role(n.hostname, n.port, role, 1, partition)
            role = 'slave'
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
