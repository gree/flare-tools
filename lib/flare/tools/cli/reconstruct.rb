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
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})") {|v| @retry = v.to_i}
          opt.on('--all',              "reconstructs all nodes") {@all = true}
        end

        def initialize
          super
          @force = false
          @safe = false
          @all = false
          @retry = 5
        end

        def execute(config, *args)
          if @all
            if args.size > 0
              puts "don't specify any nodes with --all option."
              return S_NG
            else
              Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
                cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
                args = cluster.node_list
              end
            end
          else
            return S_NG if args.size == 0
          end

          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 2
              puts "invalid argument '#{x.join(':')}'. it must be hostname:port."
              return S_NG
            end
          end
          
          status = S_OK

          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})

            hosts.each do |hostname,port|
              hostname_port = "#{hostname}:#{port}"
              nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
              cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
              
              unless node = cluster.node_stat(hostname_port)
                puts "#{hostname_port} is not found in this cluster."
                return S_NG
              end
              unless cluster.reconstructable? hostname_port
                puts "#{hostname_port} is not reconstructable."
                status = S_NG
                next
              end
              is_safe = cluster.safely_reconstructable? hostname_port
              if @safe && !is_safe
                puts "The partition needs one more slave to reconstruct #{hostname_port} safely."
                status = S_NG
                next
              end

              exec = @force
              unless exec
                puts "you are trying to reconstruct #{hostname_port} without redanduncy." unless is_safe
                input = nil
                while input.nil?
                  print "reconstructing node (node=#{hostname_port}, role=#{node['role']}) (y/n/a/q/h:help): "
                  input = interruptible do
                    gets.chomp.upcase
                  end
                  case input
                  when "A"
                    @force = true
                    exec = true
                  when "N"
                  when "Q"
                    return S_OK
                  when "Y"
                    exec = true
                  else
                    puts "y: execute, n: skip, a: execute all the left nodes, q: quit, h: help"
                    input = nil
                  end
                end
              end
              if exec
                puts "turning down..."
                s.set_state(hostname, port, 'down') unless config[:dry_run]

                puts "waiting for node to be active again..."
                sleep 3

                Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                  n.flush_all unless config[:dry_run]
                end
                nretry = 0
                resp = false
                while resp == false && nretry < @retry
                  resp = s.set_role(hostname, port, 'slave', 0, node['partition']) unless config[:dry_run]
                  if resp
                    puts "started constructing node..."
                  else
                    nretry += 1
                    puts "waiting #{nretry} sec..."
                    sleep nretry
                    puts "retrying..."
                  end
                end
                if resp
                  wait_for_slave_construction(s, hostname_port, config[:timeout]) unless config[:dry_run]
                  s.set_role(hostname, port, 'slave', node['balance'], node['partition']) unless config[:dry_run]
                  puts "done."
                else
                  error "failed to change the state."
                  return S_NG
                end
              end
              @force = false if interrupted?
            end

            puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end # open
          
          status
        end # execute()

      end
    end
  end
end
