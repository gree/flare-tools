# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

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
      class Slave < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common

        DefaultRetry = 10
        
        myname :slave
        desc   "construct slaves from proxy nodes."
        usage  "slave [hostname:port:balance:partition] ..."

        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})") {|v| @retry = v.to_i}
          opt.on('--clean',            "clears datastore before construction") {@clean = true}
        end

        def initialize
          super
          @force = false
          @retry = DefaultRetry
          @clean = false
        end

        def execute(config, *args)
          return S_NG if args.empty?

          hosts = args.map do |arg|
            hostname, port, balance, partition, rest = arg.split(':', 5)
            if rest != nil || balance.nil?
              error "invalid argument '#{arg}'. it must be hostname:port:balance:partition."
              return S_NG
            end
            [hostname, port, balance.to_i, partition.to_i]
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            cluster = fetch_cluster(s)
          
            hosts.each do |hostname,port,balance,partition|
              nodekey = nodekey_of hostname, port

              unless cluster.has_nodekey? nodekey
                error "invalid 'hostname:port' pair: #{nodekey}"
                return S_NG
              end

              node = cluster.node_stat(nodekey)

              if node['role'] != 'proxy'
                puts "#{nodekey} is not a proxy."
                next
              end
              
              exec = @force
              unless exec
                STDERR.print "making node slave (node=#{nodekey}, role=#{node['role']} -> slave) (y/n): "
                interruptible do
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec && !config[:dry_run]
                if @clean
                  Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                    n.flush_all
                  end
                end

                nretry = 0
                resp = false
                while resp == false && nretry < @retry
                  resp = s.set_role(hostname, port, 'slave', 0, partition)
                  if resp
                    puts "started constructing slave node..."
                  else
                    nretry += 1
                    puts "waiting #{nretry} sec..."
                    sleep nretry
                    puts "retrying..."
                  end
                end
                if resp
                  wait_for_slave_construction(s, nodekey, config[:timeout])
                  if balance > 0
                    unless @force
                      STDERR.print "changing node's balance (node=#{nodekey}, balance=0 -> #{balance}) (y/n): "
                      exec = interruptible {(gets.chomp.upcase == "Y")}
                    end
                    if exec
                      s.set_role(hostname, port, 'slave', balance, partition)
                    end
                  end
                else
                  error "failed to change the state."
                  return S_NG
                end
              end
            end
            STDOUT.puts string_of_nodelist(s.stats_nodes, hosts.map {|x| x[0..1].join(':')})
          end
          
          return S_OK
        end # execute()

      end
    end
  end
end
