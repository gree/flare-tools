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
      class Slave < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
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
          @retry = 10
          @clean = false
        end

        def execute(config, *args)
          return S_NG if args.size < 1

          hosts = args.map do |arg|
            hostname, port, balance, partition = arg.split(':', 5)
            if rest != nil || balance.nil?
              error "invalid argument '#{arg}'. it must be hostname:port:balance:partition."
              return S_NG
            end
            port = if port.empty? then DefaultNodePort else port.to_i end
            [hostname, port, balance.to_i, partition.to_i]
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
          
            hosts.each do |hostname,port,balance,partition|
              hostname_port = "#{hostname}:#{port}"              

              unless node = nodes.inject(false) {|r,i| if i[0] == hostname_port then i[1] else r end}
                error "invalid 'hostname:port' pair: #{hostname_port}"
                return S_NG
              end

              if node['role'] != 'proxy'
                puts "#{hostname_port} is not a proxy."
                next
              end
              
              exec = @force
              unless exec
                print "making node slave (node=#{hostname_port}, role=#{node['role']} -> slave) (y/n): "
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
                  wait_for_slave_construction(s, hostname_port, config[:timeout])
                  if balance > 0
                    unless @force
                      print "changing node's balance (node=#{hostname_port}, balance=0 -> #{balance}) (y/n): "
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
            puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end
          
          return S_OK
        end # execute()

      end
    end
  end
end
