# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/index_server'
require 'flare/util/conversion'
require 'flare/tools/cli/sub_command'

# 
module Flare
  module Tools
    module Cli

      # == Description
      # 
      class List < SubCommand
        include Flare::Util::Conversion

        myname :list
        desc   "show the list of nodes in a flare cluster."
        usage  "list"
  
        def setup(opt)
          opt.on('--numeric-hosts',            "shows numerical host addresses") {@numeric_hosts = true}
        end

        def initialize
          super
          @numeric_hosts = false
        end

        def execute(config, *args)
          header = [ ['%-32s', 'node'],
                     ['%9s', 'partition'],
                     ['%6s', 'role'],
                     ['%6s', 'state'],
                     ['%7s', 'balance'] ]
          format = header.map {|x| x[0]}.join(' ')
          
          nodes = {}
          threads = {}

          if args.size > 0
            error "invalid arguments: "+args.join(' ')
            return 1 
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'].to_i, val['role'], key]}
          end
          
          puts format % header.map{|x| x[1]}.flatten
          nodes.each do |hostname_port,data|
            ipaddr, port = hostname_port.split(":", 2)
            hostname = ipaddr
            
            if @numeric_hosts
              begin
                hostname = Resolv.getaddress(hostname)
              rescue Resolv::ResolvError
              end
            end
            
            partition = data['partition'] == "-1" ? "-" : data['partition']
            
            puts format % [
                           "#{hostname}:#{port}",
                           partition,
                           data['role'],
                           data['state'],
                           data['balance'],
                          ]
          end
          return 0
        end
        
      end
    end
  end
end
