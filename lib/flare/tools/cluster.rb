# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'rexml/document'
require 'flare/util/constant'
require 'flare/tools/common'

# 
module Flare
  module Tools

    # == Description
    # Cluster is a class that discribes a cluster information.
    class Cluster
      include Flare::Util::Constant

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

      States = { "active" => '0', "prepare" => '1', "down" => '2', "ready" => '3' }
      Roles = { "master" => '0', "slave" => '1', "proxy" => '2' }

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
                  slaves_in_partition(node[StatPartition]).inject(false) do |r, slave_nodekey|
                    r || node_stat(slave_nodekey)[State] == StateActive
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

      def serattr_ x
        return "" if x.nil?
        " class_id=\"#{x['class_id']}\" tracking_level=\"#{x['tracking_level']}\" version=\"#{x['version']}\""
      end

      def serialize(node_map_version = nil)
        thread_type = 0

        node_map_id = {"class_id"=>"0", "tracking_level"=>"0", "version"=>"0"}
        item_id = {"class_id"=>"1", "tracking_level"=>"0", "version"=>"0"}
        second_id = {"class_id"=>"2", "tracking_level"=>"0", "version"=>"0"}

        output =<<"EOS"
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<!DOCTYPE boost_serialization>
<boost_serialization signature="serialization::archive" version="4">
EOS

        if node_map_version
          output +=<<"EOS"
<version>#{node_map_version}</version>
EOS
        end

        output +=<<"EOS"
<node_map#{serattr_(node_map_id)}>
\t<count>#{@nodes.size}</count>
\t<item_version>0</item_version>
EOS
        @nodes.each do |k,v|
          node_server_name, node_server_port = k.split(':')
          node_role = Roles[v['role']]
          node_state = States[v['state']]
          node_partition = v['partition']
          node_balance = v['balance']
          node_thread_type = v['thread_type'].to_i
          
          output +=<<"EOS"
\t<item#{serattr_(item_id)}>
\t\t<first>#{k}</first>
\t\t<second#{serattr_(second_id)}>
\t\t\t<node_server_name>#{node_server_name}</node_server_name>
\t\t\t<node_server_port>#{node_server_port}</node_server_port>
\t\t\t<node_role>#{node_role}</node_role>
\t\t\t<node_state>#{node_state}</node_state>
\t\t\t<node_partition>#{node_partition}</node_partition>
\t\t\t<node_balance>#{node_balance}</node_balance>
\t\t\t<node_thread_type>#{node_thread_type}</node_thread_type>
\t\t</second>
\t</item>
EOS
          item_id = nil
          second_id  = nil
          thread_type = node_thread_type+1 if node_thread_type >= thread_type
        end
        output +=<<"EOS"
</node_map>
<thread_type>#{thread_type}</thread_type>
</boost_serialization>
EOS
        output
      end

      def self.build flare_xml
        doc = REXML::Document.new flare_xml
        nodemap = doc.elements['/boost_serialization/node_map']
        thread_type = doc.elements['/boost_serialization/thread_type']
        count = nodemap.elements['count'].get_text.to_s.to_i
        item_version = nodemap.elements['item_version'].get_text.to_s.to_i
        nodestat = []
        nodemap.elements.each('item') do |item|
          nodekey = item.elements['first'].get_text.to_s
          elem = item.elements['second'].elements
          node = {
            'server_name' => elem['node_server_name'].get_text.to_s,
            'server_port' => elem['node_server_port'].get_text.to_s,
            'role'        => elem['node_role'].get_text.to_s,
            'state'       => elem['node_state'].get_text.to_s,
            'partition'   => elem['node_partition'].get_text.to_s,
            'balance'     => elem['node_balance'].get_text.to_s,
            'thread_type' => elem['node_thread_type'].get_text.to_s
          }
          nodestat << [nodekey, node]
        end
        Cluster.new(DefaultIndexServerName, DefaultIndexServerPort, nodestat)
      end

    end
  end
end
