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
        desc   "make proxy nodes slaves."
        usage  "slave [hostname:port:balance:partition] ..."

        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})") {|v| @retry = v.to_i}
        end

        def initialize
          @force = false
          @retry = 5
        end

        def execute(config, *args)
          nodes = {}
          threads = {}

          return 1 if args.size < 1

          hosts = args.map {|x| x.split(':')}
          
          hosts.each do |x|
            if x.size != 4
              error "invalid argument '#{x.join(':')}'. it must be hostname:port:balance:partition."
              return 1
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
          
            hosts.each do |hostname,port,balance,partition|
              role = 'slave'
              
              port = if port.nil? then DefaultNodePort else port.to_i end
              hostname_port = "#{hostname}:#{port}"              
              ipaddr = address_of_hostname(hostname)

              unless node = nodes.inject(false) {|r,i| if i[0] == hostname_port then i[1] else r end}
                error "invalid 'hostname:port' pair: #{hostname_port}"
                return 1
              end
              
              exec = false
              if @force
                exec = true
              elsif node['role'] != 'proxy'
                puts "#{ipaddr}:#{port} is not a proxy."
              else
                print "making node slave (node=#{ipaddr}:#{port}, role=#{node['role']} -> #{role}) (y/n): "
                interruptible do
                  exec = true if gets.chomp.upcase == "Y"
                end
              end
              if exec
                resp = false
                nretry = 0
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
                  s.set_role(hostname, port, role, balance, partition) unless config[:dry_run]
                end
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
