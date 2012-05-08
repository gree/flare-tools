# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

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
        desc   "remove a node. (experimental)"
        usage  "remove"
  
        def setup(opt)
          opt.on('--force',            "commit changes without confirmation")                  {@force = true}
          opt.on('--wait=[SECOND]',    "specify the time to wait node for getting ready (default:#{@wait})") {|v| @wait = v.to_i}
          opt.on('--retry=[COUNT]',    "retry count(default:#{@retry})")                        {|v| @retry = v.to_i}
          opt.on('--connection-threshold=[COUNT]', "specify connection threashold (default:#{@connection_threshold})") {|v| @connection_threshold = v.to_i}
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
            cluster = fetch_cluster(s)

            hosts.each do |hostname,port|
              nodekey = nodekey_of hostname, port
              unless cluster.has_nodekey? nodekey
                error "unknown node name: #{nodekey}"
                return S_NG
              end
            end

            hosts.each do |hostname,port|
              exec = false
              Flare::Tools::Node.open(hostname, port, config[:timeout]) do |n|
                nwait = @wait
                node = n.stats
                cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
                while nwait > 0
                  conn = node['curr_connections'].to_i
                  cluster = fetch_cluster(s)
                  role = cluster.node_stat("#{hostname}:#{port}")['role']
                  info "waiting until #{hostname}:#{port} (role=#{role}, connections=#{conn}) is inactive..."
                  if conn <= @connection_threshold && role == 'proxy'
                    exec = true
                    break
                  end
                  interruptible {sleep 1}
                  nwait -= 1
                  node = n.stats
                end
                unless @force
                  node_stat = cluster.node_stat("#{hostname}:#{port}")
                  role = node_stat['role']
                  state = node_stat['state']
                  print "please shutdown the daemon and continue (node=#{hostname}:#{port}, role=#{role}, state=#{state}) (y/n): "
                  interruptible {
                    exec = false if gets.chomp.upcase != "Y"
                  }
                end
              end
              
              if exec
                suc = false
                nretry = @retry
                while nretry > 0
                  resp = false
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
