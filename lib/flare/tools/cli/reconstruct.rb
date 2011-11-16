# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/stats'
require 'flare/tools/node'
require 'flare/tools/index_server'
require 'flare/tools/cluster'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'

module Flare
  module Tools
    module Cli
      class Reconstruct < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :reconstruct
        desc "reconstruct the database of nodes by copying."
        usage "reconstruct [hostname:port] ..."

        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
          opt.on('--safe',             "reconstructs a node safely") {@safe = true}
        end

        def initialize
          @force = false
          @safe = false
        end

        def execute(config, *args)
          return 1 if args.size < 1
          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 2
              puts "invalid argument '#{x.join(':')}'. it must be hostname:port."
              return 1
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            hosts.each do |hostname,port|
              hostname_port = "#{hostname}:#{port}"
              nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
              cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
              
              unless node = cluster.node_stat(hostname_port)
                error "#{hostname_port} is not found in this cluster."
                return 1
              end
              unless cluster.reconstructable? hostname_port
                error "#{hostname_port} is not reconstructable."
                return 1
              end
              is_safe = cluster.safely_reconstructable? hostname_port
              if @safe && !is_safe
                error "The partition needs one more slave to reconstruct #{hostname_port} safely."
                return 1
              end

              exec = false
              if @force
                exec = true
              else
                warn "you have no redanduncy of this partition while reconstructing #{hostname_port}." unless is_safe
                print "reconstructing node (node=#{hostname_port}, role=#{node['role']}) (y/n): "
                interruptible do
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec
                STDERR.print "turning down..."
                s.set_state(hostname, port, 'down') unless config[:dry_run]
                STDERR.print "\n"

                STDERR.print "waiting for node to be active again..."
                sleep 3
                STDERR.print "\n"

                Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                  n.flush_all unless config[:dry_run]
                end
                s.set_role(hostname, port, 'slave', 0, node['partition']) unless config[:dry_run]
                STDERR.puts "started constructing node..."
                wait_for_slave_construction(s, hostname_port, config[:timeout]) unless config[:dry_run]
                s.set_role(hostname, port, 'slave', node['balance'], node['partition']) unless config[:dry_run]
              end
            end

            puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end
          
          return 0
        end # execute()

      end
    end
  end
end
