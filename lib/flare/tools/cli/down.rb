# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/stats'
require 'flare/tools/node'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/tools/cluster'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'

module Flare
  module Tools
    module Cli
      
      class Down < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :down
        desc   "turn down nodes and destroy their data."
        usage  "down [hostname:port] ..."
        
        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
        end

        def initialize
          super
          @force = false
        end

        def execute(config, *args)
          return S_NG if args.size < 1

          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size != 2
              puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
          
            hosts.each do |hostname,port|
              down = 'down'
              nodekey = nodekey_of hostname, port
              ipaddr = address_of_hostname(hostname)
          
              unless cluster.has_nodekey? nodekey
                error "invalid 'hostname:port' pair: #{nodekey}"
                return S_NG
              end

              node = cluster.node_stat(nodekey)

              exec = @force
              if exec
              elsif node['state'] == down
                puts "#{ipaddr}:#{port} is already down."
              else
                print "turning node down (node=#{ipaddr}:#{port}, state=#{node['state']} -> #{down}) (y/n): "
                exec = interruptible {(gets.chomp.upcase == "Y")}
              end
              if exec
                s.set_state(hostname, port, down) unless config[:dry_run]
              end
            end

            puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end
          
          S_OK
        end # execute()
        
        def stat_one_node(s)
          
        end

      end
    end
  end
end
