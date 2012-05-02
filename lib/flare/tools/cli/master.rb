# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/stats'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'

module Flare
  module Tools
    module Cli
      class Master < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common

        myname :master
        desc   "construct a partition with a master."
        usage  "master [hostname:port:balance:partition] ..."

        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})") {|v| @retry = v.to_i}
          opt.on('--activate',         "changes node's state from ready to active") {@activate = true}
        end

        def initialize
          @force = false
          @retry = 10
          @activate = false
        end
  
        def execute(config, *args)
          return S_NG if args.size < 1
          status = S_OK
          
          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 4
              error "invalid argument '#{x.join(':')}'."
              return S_NG
            end
            if x[2].to_i <= 0
              error "invalid balance '#{x.join(':')}'."
              return S_NG
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key,val| [val['partition'], val['role'], key]}
            hosts.each do |hostname,port,balance,partition|
              cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
              role = 'master'
              port = if port == '' then DefaultNodePort else port.to_i end
              hostname_port = "#{hostname}:#{port}"
              ipaddr = address_of_hostname(hostname)
          
              unless node = nodes.inject(false) {|r,i| if i[0] == hostname_port then i[1] else r end}
                error "unknown host: #{hostname_port}"
                return S_NG
              end

              partition = if partition == '' then node['partition'].to_i else partition.to_i end
              balance = if balance == '' then node['balance'] else balance.to_i end
              existing_master = cluster.master_in_partition(partition)

              exec = false
              if @force
                exec = true
              elsif node['role'] == role
                info "no need to change the role of #{ipaddr}:#{port}."
              elsif existing_master
                info "the partiton already has a master #{existing_master}."
              else
                STDOUT.print "making the node master (node=#{ipaddr}:#{port}, role=#{node['role']} -> #{role}) (y/n): "
                exec = interruptible {(gets.chomp.upcase == "Y")}
              end
              if exec && !config[:dry_run]
                nretry = 0
                resp = false
                while resp == false && nretry < @retry
                  resp = s.set_role(hostname, port, role, balance, partition)
                  if resp
                    info "started constructing master node..."
                  else
                    nretry += 1
                    info "waiting #{nretry} sec..."
                    sleep nretry
                    info "retrying..."
                  end
                end
                if resp
                  wait_for_master_construction(s, hostname_port, config[:timeout])
                  if @activate || partition == 0
                    unless @force || partition == 0
                      node = s.stats_nodes[hostname_port]
                      STDOUT.print "changing node's state (node=#{ipaddr}:#{port}, state=#{node['state']} -> active) (y/n): "
                      exec = interruptible {
                        (gets.chomp.upcase == "Y")
                      }
                    end
                    if exec
                      resp = s.set_state(hostname, port, 'active')
                      status = S_NG unless resp
                    end
                  end
                else
                  error "failed to change the state."
                  status = S_NG
                end
              end
            end
            STDOUT.puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end

          status
        end # execute()
        
        def stat_one_node(s)
          
        end

      end
    end
  end
end
