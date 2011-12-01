# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/index_server'
require 'flare/util/conversion'
require 'flare/tools/common'
require 'flare/tools/cli/sub_command'

# 
module Flare
  module Tools
    module Cli

      # == Description
      # 
      class Remove < SubCommand
        include Flare::Util::Conversion
        include Flare::Tools::Common

        myname :remove
        desc   "show the list of nodes in a flare cluster."
        usage  "remove"
  
        def setup(opt)
          opt.on('--force',            "commits changes without confirmation") {@force = true}
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})") {|v| @retry = v.to_i}
        end

        def initialize
          super
          @force = false
          @retry = 30
        end

        def execute(config, *args)
          nodes = {}
          threads = {}

          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size != 2
              error "invalid argument '#{x.join(':')}'. it must be hostname:port."
              return S_NG
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|

            hosts.each do |hostname,port|
              nodes = s.stats_nodes

              unless @force
                Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                  nretry = @retry
                  until nretry > 0
                    interruptible do
                      sleep 1
                    end
                    conn = n.node_stats['conn'].to_i
                    info "waiting until the number of connections #{conn} becomes 2..."
                    nretry = nretry-1
                  end
                end
              end
              s.set_state(hostname, port, 'down') unless config[:dry_run]
              s.node_remove(hostname, port) unless config[:dry_run]
            end

            puts string_of_nodelist(s.stats_nodes)
          end
          
          return S_OK
        end
        
      end
    end
  end
end
