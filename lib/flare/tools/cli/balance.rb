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
          return 1 if args.size < 1

          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 3
              puts "invalid argument '#{x.join(':')}'."
              return 1
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key,val| [val['partition'], val['role'], key]}
            hosts.each do |hostname,port,balance|
              balance = balance.to_i
              port = if port == '' then DefaultNodePort else port.to_i end
              hostname_port = "#{hostname}:#{port}"
              ipaddr = address_of_hostname(hostname)
          
              unless node = nodes.inject(false) {|r,i| if i[0] == hostname_port then i[1] else r end}
                error "unknown host: #{hostname_port}"
                return 1
              end

              exec = false
              if @force
                exec = true
              elsif node['balance'].to_i == balance
                puts "no need to change the balance of #{ipaddr}:#{port}."
              else
                interruptible do
                  print "updating node balance (node=#{ipaddr}:#{port}, balance=#{node['balance']} -> #{balance}) (y/n): "
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec
                s.set_role(hostname, port.to_i, node['role'], balance, node['partition']) unless config[:dry_run]
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
