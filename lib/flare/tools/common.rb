# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'resolv'
require 'flare/tools/cluster'
require 'flare/tools/stats'
require 'flare/util/constant'
require 'flare/util/logging'

# 
module Flare
  module Tools
    module Common
      include Flare::Util::Logging

      def fetch_cluster s
        Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
      end

      def confirm? opt = /^Y$/, &block
        line = gets.chomp.upcase
        ret = if block.nil?
                opt =~ line
              else
                if opt.nil?
                  block.call(line)
                else
                  block.call(line) if opt =~ line
                end
              end
        ret
      end

      def nodekey_of *args
        if args.size == 1
          args = if args[0].kind_of?(Array)
                   args[0]
                 elsif args[0].kind_of?(String)
                   args[0].split(':')
                 end
        end
        if args.size >= 2
          hostname, port = args
          if hostname.kind_of?(String) && port.kind_of?(String)
            if port.empty?
              port = Flare::Util::Constant::DefaultNodePort
              return "#{hostname}:#{port}"
            elsif /^\d+$/ =~ port
              return "#{hostname}:#{port}"
            end
          elsif hostname.kind_of?(String) && port.kind_of?(Integer)
            return "#{hostname}:#{port}"
          end
        end
        nil
      end

      def address_of_hostname(hostname)
        Resolv.getaddress(hostname)
      rescue Resolv::ResolvError
        hostname
      end

      def hostname_of_address(ipaddr)
        Resolv.getname(ipaddr)
      rescue Resolv::ResolvError
        ipaddr
      end
      
      NodeListHeader = [ ['%-32s', 'node'],
                         ['%9s', 'partition'],
                         ['%6s', 'role'],
                         ['%6s', 'state'],
                         ['%7s', 'balance'] ]
      NodeListFormat = (NodeListHeader.map {|x| x[0]}.join(' '))

      def string_of_nodelist(nodes, opt = {})
        format = NodeListFormat+"\n"
        ret = format % NodeListHeader.map{|x| x[1]}.flatten
        nodes.each do |nodekey, node|
          if opt.empty? || opt.include?(nodekey)
            partition = if node['partition'] == "-1"
                          "-"
                        else
                          node['partition']
                        end
            ret += format % [
                             nodekey,
                             partition,
                             node['role'],
                             node['state'],
                             node['balance'],
                            ]
          end
        end
        ret
      end

      # s:IndexServer, nodekey:"hostname:port", timeout(second):Integer -> state:String
      def wait_for_slave_construction(index_server, nodekey, timeout, silent = false)
        cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
        slave = cluster.node_stat(nodekey)
        partition = slave['partition'].to_i
        m_hostname, m_port = cluster.master_in_partition(partition).split(':')
        s_hostname, s_port = nodekey.split(':')
        m = Flare::Tools::Stats.open(m_hostname, m_port.to_i, timeout)
        s = Flare::Tools::Stats.open(s_hostname, s_port.to_i, timeout)
        start = Time.now
        while true
          cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
          slave = cluster.node_stat(nodekey)
          stats_master = m.stats
          stats_slave = s.stats
          ts_diff = Time.now-start
          state_slave = slave['state'];
          role_slave = slave['role'];
          item_m = stats_master['curr_items'].to_i;
          item_s = stats_slave['curr_items'].to_i;
          eta = if ts_diff > 0 && item_s > 0
                  ((item_m - item_s) / (item_s / ts_diff)).to_i;
                  else
                  "n/a";
                end
          unless silent
            STDERR.puts "%d/%d (role = %s, state = %s) [ETA: %s sec (elapsed = %d sec)]" % [item_s, item_m, role_slave, state_slave, eta, ts_diff]
          end
          break if role_slave == "slave" && state_slave == "active"
          sleep 1
        end
        info "state is active -> stop waiting" unless silent
        m.close
        s.close
        state_slave
      end

      # s:IndexServer, nodekey:"hostname:port", timeout(second):Integer -> state:String
      def wait_for_master_construction(index_server, nodekey, timeout, silent = false)
        cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
        master = cluster.node_stat(nodekey)
        partition = master['partition'].to_i
        m_hostname, m_port = cluster.master_in_partition(partition).split(':')
        m = Flare::Tools::Stats.open(m_hostname, m_port.to_i, timeout)
        start = Time.now
        while true
          cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
          master = cluster.node_stat(nodekey)
          stats_master = m.stats
          ts_diff = Time.now-start
          state_master = master['state'];
          role_master = master['role'];
          item_m = stats_master['curr_items'].to_i;
          eta = "n/a";
          unless silent
            STDERR.puts "%d (role = %s, state = %s) [ETA: %s sec (elapsed = %d sec)]" % [item_m, role_master, state_master, eta, ts_diff]
          end
          if role_master == "master" && state_master == "active"
            if partition != 0
              warn "The master should be ready after the reconstruction but it became active."
            end
            break
          end
          break if role_master == "master" && state_master == "ready"
          sleep 1
        end
        info "state is ready -> stop waiting" unless silent
        m.close
        state_master
      end

      def wait_for_servers(index_server, timeout = Flare::Util::Constant::DefaultTimeout, silent = false)
        index_server.stats_nodes.each do |nodekey, v|
          hostname, port = nodekey.split(':')
          is_alive = false
          while is_alive
            begin
              Flare::Tools::Node.open(hostname, port.to_i, 2) do |n|
                n.ping
                is_alize = true
              end
            rescue Errno::ECONNREFUSED
            rescue SocketError
            end
            sleep 1 unless is_alive
          end
        end
      end

    end
  end
end
