# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'resolv'
require 'flare/tools/cluster'
require 'flare/tools/stats'
require 'flare/util/constant'

# 
module Flare
  module Tools
    module Common
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
        nodes.each do |hostname_port, node|
          if opt.empty? || opt.include?(hostname_port)
            ret += format % [
                             hostname_port,
                             node['partition'],
                             node['role'],
                             node['state'],
                             node['balance'],
                            ]
          end
        end
        ret
      end

      # s:IndexServer, hostname_port:"hostname:port", timeout:Integer(second)
      def wait_for_slave_construction(index_server, hostname_port, timeout, silent = false)
        cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
        slave = cluster.node_stat(hostname_port)
        partition = slave['partition'].to_i
        m_hostname, m_port = cluster.master_in_partition(partition).split(':')
        s_hostname, s_port = hostname_port.split(':')
        m = Flare::Tools::Stats.open(m_hostname, m_port.to_i, timeout)
        s = Flare::Tools::Stats.open(s_hostname, s_port.to_i, timeout)
        start = Time.now
        while true
          cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
          slave = cluster.node_stat(hostname_port)
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
            puts "%d/%d (role = %s, state = %s) [ETA: %s sec (elapsed = %d sec)]" % [item_s, item_m, role_slave, state_slave, eta, ts_diff]
          end
          break if role_slave == "slave" && state_slave == "active"
          sleep 1
        end
        puts "state is active -> stop waiting" unless silent
        m.close
        s.close
      end

      # s:IndexServer, hostname_port:"hostname:port", timeout:Integer(second)
      def wait_for_master_construction(index_server, hostname_port, timeout, silent = false)
        cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
        master = cluster.node_stat(hostname_port)
        partition = master['partition'].to_i
        m_hostname, m_port = cluster.master_in_partition(partition).split(':')
        m = Flare::Tools::Stats.open(m_hostname, m_port.to_i, timeout)
        start = Time.now
        while true
          cluster = Flare::Tools::Cluster.new(index_server.host, index_server.port, index_server.stats_nodes)
          master = cluster.node_stat(hostname_port)
          stats_master = m.stats
          ts_diff = Time.now-start
          state_master = master['state'];
          role_master = master['role'];
          item_m = stats_master['curr_items'].to_i;
          eta = "n/a";
          unless silent
            puts "%d (role = %s, state = %s) [ETA: %s sec (elapsed = %d sec)]" % [item_m, role_master, state_master, eta, ts_diff]
          end
          break if role_master == "master" && state_master == "ready"
          break if role_master == "master" && state_master == "active" # XXX
          sleep 1
        end
        puts "state is ready -> stop waiting" unless silent
        m.close
      end

      def wait_for_servers(index_server, timeout = Flare::Util::Constant::DefaultTimeout, silent = false)
        index_server.stats_nodes.each do |hostname_port, v|
          hostname, port = hostname_port.split(':')
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
