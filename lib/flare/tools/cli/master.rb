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
        desc   "set the master of a partition."
        usage  "master [hostname:port:balance:partition] ..."

        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
        end

        def initialize
          @force = false
        end
  
        def execute(config, *args)
          return 1 if args.size < 1

          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 4
              puts "invalid argument '#{x.join(':')}'."
              return 1
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
                return 1
              end

              partition = if partition == '' then node['partition'].to_i else partition.to_i end
              balance = if balance == '' then node['balance'] else balance.to_i end
              existing_master = cluster.master_in_partition(partition)

              exec = false
              if @force
                exec = true
              elsif node['role'].to_i == role
                puts "no need to change the role of #{ipaddr}:#{port}."
              elsif existing_master
                puts "the partiton already has a master #{existing_master}."
              else
                print "making the node master (node=#{ipaddr}:#{port}, role=#{node['role']} -> #{role}) (y/n): "
                interruptible do
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec
                resp = s.set_role(hostname, port, role, balance, partition) unless config[:dry_run]
                if resp
                  wait_for_master_construction(s, hostname_port, config[:timeout])
                end
              end
            end
            puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end

          return 0
        end # execute()
        
        def stat_one_node(s)
          
        end

      end
    end
  end
end
