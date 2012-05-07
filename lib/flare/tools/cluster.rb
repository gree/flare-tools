# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/util/constant'
require 'flare/tools/common'

# 
module Flare
  module Tools

    # == Description
    # Cluster is a class that discribes a cluster information.
    class Cluster
      State = 'state'
      Role  = 'role'
      StateActive  = 'active'
      StateDown    = 'down'
      StateReady   = 'ready'
      StatePrepare = 'prepare'
      RoleProxy  = 'proxy'
      RoleMaster = 'master'
      RoleSlave  = 'slave'
      StatPartition = 'partition'

      class NodeStat
        def initialize stat
          @stat = stat.dup
        end

        def [](i)
          @stat[i]
        end

        def []=(i, v)
          @stat[i] = v.to_s
        end

        def master?
          (role == RoleMaster)
        end

        def slave?
          (role == RoleSlave)
        end

        def proxy?
          (role == RoleProxy)
        end

        def active?
          (state == StateActive)
        end

        def ready?
          (state == StateReady)
        end
        
        def down?
          (state == StateDown)
        end

        def prepare?
          (state == StatePrepare)
        end

        def partition
          @stat['partition'].to_i
        end

        def thread_type
          @stat['thread_type'].to_i
        end

        def balance
          @stat['balance'].to_i
        end
        
        def method_missing(action, *args)
          if @stat.has_key? action.to_s
            @stat[action.to_s]
          else
            @stat.__send__(action, *args)
          end
        end
      end

      def initialize(index_server_hostname, index_server_port, nodes_stat)
        @index_server_hostname = index_server_hostname
        @index_server_port = index_server_port
        @nodes_stat = nodes_stat
        max_partition = -1
        nodes_stat.each do |nodekey,node_stat|
          p = node_stat[StatPartition].to_i
          max_partition = p if p > max_partition
        end
        @partition = if max_partition >= 0
                       (0..max_partition).map {Hash.new}
                     else
                       []
                     end
        @partition_size = max_partition+1
        nodes_stat.each do |nodekey,node_stat|
          p = node_stat[StatPartition].to_i
          @partition[p][nodekey] = node_stat if p >= 0
        end
        @nodes = {}
        nodes_stat.each do |k,v|
          @nodes[k] = NodeStat.new(v)
        end
      end

      # check if the partition of a nodekey has at least one active slave
      def reconstructable?(nodekey)
        node = node_stat(nodekey)
        ret = if node[State] == StateActive
                case node[Role]
                when RoleProxy
                  false
                when RoleSlave
                  true
                when RoleMaster
                  # if the partition has at least one active slave, one of the slaves will take over the master.
                  slaves_in_partition(node[StatPartition]).inject(false) do |r,slave_nodekey|
                    node_stat(slave_nodekey)[State] == StateActive
                  end
                else
                  error "unknown role: #{node[Role]}"
                  false
                end
              else
                false
              end
        ret
      end

      def safely_reconstructable?(nodekey)
        node = node_stat(nodekey)
        return false if node[State] != StateActive
        case node[Role]
        when RoleProxy
          false
        when RoleSlave
          slaves_in_partition(node[StatPartition]).inject(false) do |r, slave_nodekey|
            if slave_nodekey != nodekey
              node_stat(slave_nodekey)[State] == StateActive
            else
              r
            end
          end
        when RoleMaster
          count = slaves_in_partition(node[StatPartition]).inject(0) do |r, slave_nodekey|
            if node_stat(slave_nodekey)[State] == StateActive then r+1 else r end
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
          nodekey, node = i
          if node[Role] == RoleMaster then nodekey else r end
        }
      end

      def slaves_in_partition(p)
        return nil if partition(p).nil?
        partition(p).inject([]) {|r,i| if i[1][Role] == RoleSlave then r << i[0] else r end}
      end
      
      def nodekeys_(&block)
        unordered = if block.nil?
                      @nodes.keys
                    else
                      ret = []
                      @nodes.each do |k,v|
                        ret << k if block.call(v)
                      end
                      ret
                    end
        unordered.sort_by do |i|
          p = @nodes[i].partition
          p = @partition_size if p < 0
          [p, @nodes[i].role, i]
        end
      end
      
      def nodekeys
        nodekeys_
      end

      def master_nodekeys
        nodekeys_ {|v| v[Role] == RoleMaster }
      end

      def master_and_slave_nodekeys
        nodekeys_ {|v| v[Role] == RoleMaster || v[Role] == RoleSlave }
      end

      def node_stat(nodekey)
        @nodes[nodekey]
      end
      
      def size
        @nodes.size
      end

      def partition_size
        @partition_size
      end

      # proxy -> -1
      # not found -> nil
      def partition_of_nodename node
        @nodes.each do |k,v|
          return v[StatPartition].to_i if k == node
        end
        return nil
      end

      def has_nodekey?(nodekey)
        @nodes.has_key? nodekey
      end

    end
  end
end

