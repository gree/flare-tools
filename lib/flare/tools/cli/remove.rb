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
          opt.on('--wait=[SECOND]',    "time to wait node for getting ready(default:#{@wait})") {|v| @wait = v.to_i}
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})") {|v| @retry = v.to_i}
          opt.on('--connection-threshold=[COUNT]',    "connection threashold(default:#{@connection_threshold})") {|v| @connection_threshold = v.to_i}
        end

        def initialize
          super
          @force = false
          @wait = 30
          @retry = 5
          @connection_threshold = 2
        end

        def execute(config, *args)
          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size != 2
              error "invalid argument '#{x.join(':')}'. it must be hostname:port."
              return S_NG
            end
          end
          
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|

            hosts.each do |hostname,port|
              exec = false
              Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                nwait = @wait
                while nwait > 0
                  stats = n.stats
                  conn = stats['curr_connections'].to_i
                  cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
                  role = cluster.node_stat("#{hostname}:#{port}")['role']
                  info "waiting until #{hostname}:#{port}(role=#{role}, connections=#{conn}) is inactive..."
                  if conn <= @connection_threshold && role == 'proxy'
                    exec = true
                    break
                  end
                  interruptible {sleep 1}
                  nwait -= 1
                end
              end
              if exec
                suc = false
                nretry = @retry
                while nretry > 0
                  resp = false
                  info "turning down #{hostname}:#{port}."
                  s.set_state(hostname, port, 'down') unless config[:dry_run]
                  info "removing #{hostname}:#{port}."
                  resp = s.node_remove(hostname, port) unless config[:dry_run]
                  if resp
                    suc = true
                    break
                  end
                  nretry -= 1
                end
                info "done." if suc
                info "failed." unless suc
              else
                info "skipped."
              end
            end
            puts string_of_nodelist(s.stats_nodes)
          end
          
          S_OK
        end
        
      end
    end
  end
end
