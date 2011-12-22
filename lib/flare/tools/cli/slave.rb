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
          opt.on('--retry=[COUNT]',    "retries count(default:#{@retry})") {|v| @retry = v.to_i}
          opt.on('--clean',            "clears datastore before construction") {@clean = true}
          opt.on('--keep-inactive',    "keeps new slave's balance 0") {@keep_inactive = true}
        end

        def initialize
          super
          @force = false
          @retry = 5
          @clean = false
          @keep_inactive = false
        end

        def execute(config, *args)
          return S_NG if args.size < 1

          hosts = args.map do |arg|
            hostname, port, balance, partition, rest = arg.split(':', 5)
            unless rest.nil?
              error "invalid argument '#{arg}'. it must be hostname:port:balance:partition."
              return S_NG
            end
            port = if port.empty? then DefaultNodePort else port.to_i end
            [hostname, port, balance.to_i, partition.to_i]
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
          
            hosts.each do |hostname,port,balance,partition|
              role = 'slave'
              
              hostname_port = "#{hostname}:#{port}"              
              ipaddr = address_of_hostname(hostname)

              unless node = nodes.inject(false) {|r,i| if i[0] == hostname_port then i[1] else r end}
                error "invalid 'hostname:port' pair: #{hostname_port}"
                return S_NG
              end

              if node['role'] != 'proxy'
                puts "#{ipaddr}:#{port} is not a proxy."
                next
              end
              
              exec = @force
              unless exec
                print "making node slave (node=#{ipaddr}:#{port}, role=#{node['role']} -> #{role}) (y/n): "
                interruptible do
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec
                if @clean
                  Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                    n.flush_all unless config[:dry_run]
                  end
                end

                nretry = 0
                resp = false
                while resp == false && nretry < @retry
                  resp = s.set_role(hostname, port, role, 0, partition) unless config[:dry_run]
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
                  wait_for_slave_construction(s, hostname_port, config[:timeout]) unless config[:dry_run]
                  unless @keep_inactive || balance == 0
                    unless @force
                      print "changing node's balance (node=#{ipaddr}:#{port}, balance=0 -> #{balance}) (y/n): "
                      exec = interruptible {(gets.chomp.upcase == "Y")}
                    end
                    if exec
                      s.set_role(hostname, port, role, balance, partition) unless config[:dry_run]
                    end
                  end
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
