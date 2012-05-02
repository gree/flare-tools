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

        HeaderConfig = [ ['%-32s', 'node'],
                         ['%9s',   'partition'],
                         ['%6s',   'role'],
                         ['%6s',   'state'],
                         ['%7s',   'balance'] ]
  
        def setup(opt)
          opt.on('--numeric-hosts',            "shows numerical host addresses") {@numeric_hosts = true}
        end

        def initialize
          super
          @numeric_hosts = false
          @format = HeaderConfig.map {|x| x[0]}.join(' ')
          @cout = STDOUT
        end

        def print_header
          @cout.puts @format % HeaderConfig.map{|x| x[1]}.flatten
          nil
        end

        def print_node *args
          @cout.puts @format % args
          nil
        end
        
        def get_address_or_remain hostname
          begin
            Resolv.getaddress(hostname)
          rescue Resolv::ResolvError
            hostname
          end
        end

        def execute(config, *args)
          if args.size > 0
            error "invalid arguments: "+args.join(' ')
            return S_NG
          end
          
          nodes = Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            stats_nodes = s.stats_nodes
            stats_nodes.sort_by{|key, val| [val['partition'].to_i, val['role'], key]} unless stats_nodes.nil?
          end

          if nodes.nil?
            error "Invalid index server."
            return S_NG
          end
          
          print_header
          nodes.each do |hostname_port,data|
            hostname, port = hostname_port.split(":", 2)
            hostname = get_address_or_remain(hostname) if @numeric_hosts
            partition = (data['partition'] == "-1") ? "-" : data['partition']
            print_node "#{hostname}:#{port}", partition, data['role'], data['state'], data['balance']
          end

          S_OK
        end
        
      end
    end
  end
end
