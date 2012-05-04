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
      class Balance < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common

        myname :balance
        desc   "set the balance values of nodes."
        usage  "balance [hostname:port:balance] ..."

        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
        end

        def initialize
          @force = false
        end
  
        def execute(config, *args)
          return S_NG if args.empty?

          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 3
              puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)

            hosts.each do |hostname,port,balance|
              balance = balance.to_i
              nodekey = nodekey_of hostname, port
              ipaddr = address_of_hostname(hostname)
          
              unless cluster.has_nodekey? nodekey
                error "unknown host: #{nodekey}"
                return S_NG
              end

              node = cluster.node_stat(nodekey)

              exec = false
              if @force
                exec = true
              elsif node['balance'].to_i == balance
                STDERR.puts "no need to change the balance of #{ipaddr}:#{port}."
              else
                interruptible do
                  STDERR.print "updating node balance (node=#{ipaddr}:#{port}, balance=#{node['balance']} -> #{balance}) (y/n): "
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec
                s.set_role(hostname, port.to_i, node['role'], balance, node['partition']) unless config[:dry_run]
              end
            end
            STDOUT.puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end

          return S_OK
        end # execute()
        
        def stat_one_node(s)
          
        end

      end
    end
  end
end
