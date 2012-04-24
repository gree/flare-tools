# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/util/constant'

# 
module Flare
  module Tools

    # == Description
    # Cluster is a class that discribes a cluster information.
    class Cluster
      StateActive = 'active'
      StateDown   = 'down'
      RoleProxy = 'proxy'
      RoleMaster = 'master'
      RoleSlave = 'slave'

      def initialize(index_server_hostname, index_server_port, nodes_stat)
        @index_server_hostname = index_server_hostname
        @index_server_port = index_server_port
        @nodes_stat = nodes_stat
        max_partition = 0
        nodes_stat.each do |hostname_port,node_stat|
          p = node_stat['partition'].to_i
          max_partition = p if p > max_partition
        end
        @partition = (0..max_partition).map {Hash.new}
        nodes_stat.each do |hostname_port,node_stat|
          p = node_stat['partition'].to_i
          @partition[p][hostname_port] = node_stat
        end
        @nodes = {}
        nodes_stat.each do |k,v|
          @nodes[k] = v
        end
      end

      def reconstructable?(hostname_port)
        node = node_stat(hostname_port)
        return false if node['state'] != StateActive
        case node['role']
        when RoleProxy
          false
        when RoleSlave
          true
        when RoleMaster
          # if the partition has at least one active slave, one of the slaves will take over the master.
          slaves_in_partition(node['partition']).inject(false) do |r, slave_hostname_port|
            node_stat(slave_hostname_port)['state'] == StateActive
          end
        end
      end

      def safely_reconstructable?(hostname_port)
        node = node_stat(hostname_port)
        return false if node['state'] != StateActive
        case node['role']
        when RoleProxy
          false
        when RoleSlave
          slaves_in_partition(node['partition']).inject(false) do |r, slave_hostname_port|
            if slave_hostname_port != hostname_port
              node_stat(slave_hostname_port)['state'] == StateActive
            else
              r
            end
          end
        when RoleMaster
          count = slaves_in_partition(node['partition']).inject(0) do |r, slave_hostname_port|
            if node_stat(slave_hostname_port)['state'] == StateActive then r+1 else r end
          end
          (count >= 2)
        else
          raise "internal error."
        end
      end

      def partition(p)
        @partition[p.to_i]
      end

      def master_in_partition(p)
        return nil if partition(p).nil?
        partition(p).inject(nil) {|r,i|
          hostname_port, node = i
          if node['role'] == RoleMaster then hostname_port else r end
        }
      end

      def slaves_in_partition(p)
        return nil if partition(p).nil?
        partition(p).inject([]) {|r,i| if i[1]['role'] == RoleSlave then r << i[0] else r end}
      end
      
      def node_list
        @nodes.keys
      end

      def master_node_list
        ret = []
        @nodes.each do |k,v|
          ret << k if v['role'] == RoleMaster
        end
        ret
      end

      def node_stat(hostname_port)
        @nodes[hostname_port]
      end
      
      def size
        @nodes.size
      end
      
    end
  end
end

