# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/stats'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/tools/cluster'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'
require 'flare/tools/cli/index_server_config'

module Flare
  module Tools
    module Cli
      class Master < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        include Flare::Tools::Cli::IndexServerConfig

        myname :master
        desc   "construct a partition with a proxy node for master role."
        usage  "master [hostname:port:balance:partition] ..."

        def setup
          super
          set_option_index_server
          set_option_dry_run
          set_option_force
          @optp.on('--retry=COUNT', "specify retry count (default:#{@retry})" ) {|v| @retry = v.to_i }
          @optp.on('--activate', "change node's state from ready to active") { @activate = true }
          @optp.on('--without-clean', "don't clear datastore before construction") { @without_clean = true }
        end

        def initialize
          super
          @force = false
          @retry = 10
          @activate = false
          @without_clean = false
        end

        def execute(config, args)
          parse_index_server(config, args)
          status = S_OK

          return S_NG if args.empty?
          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 4
              error "invalid argument '#{x.join(':')}'."
              return S_NG
            end
            if x[2].to_i <= 0
              error "invalid balance '#{x.join(':')}'."
              return S_NG
            end
            if nodekey_of(x[0..1]).nil?
              error "invalid nodekey '#{x.join(':')}'."
              return S_NG
            end
          end
          hosts = hosts.sort_by{|hostname,port,balance,partition| [partition]}

          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], @timeout) do |s|
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)

            hosts.each do |hostname,port,balance,partition|
              role = 'master'
              nodekey = nodekey_of hostname, port
              ipaddr = address_of_hostname(hostname)

              unless cluster.has_nodekey? nodekey
                error "unknown host: #{nodekey}"
                # return S_NG
              end

              node = cluster.node_stat(nodekey)

              partition = if partition == '' then node['partition'].to_i else partition.to_i end
              balance = if balance == '' then node['balance'] else balance.to_i end
              existing_master = cluster.master_in_partition(partition)

              exec = false
              if @force
                exec = true
              elsif node['role'] == role
                info "no need to change the role of #{ipaddr}:#{port}."
              elsif existing_master
                info "the partiton already has a master #{existing_master}."
              elsif node['role'] != 'proxy'
                puts "#{nodekey} is not a proxy."
              else
                clean_notice_base = "\nitems stored in the node will be cleaned up (exec flush_all) before constructing it"
                clean_notice = @without_clean ? clean_notice_base : ''
                STDERR.print "making the node master (node=#{ipaddr}:#{port}, role=#{node['role']} -> #{role})#{clean_notice} (y/n): "
                exec = interruptible {(gets.chomp.upcase == "Y")}
              end
              if exec && !@dry_run
                unless @without_clean
                  resp = false
                  Flare::Tools::Node.open(hostname, port, @timeout) do |n|
                    resp = n.flush_all
                  end
                  unless resp
                    STDERR.print "executing flush_all failed."
                    return S_NG
                  end
                  puts "executed flush_all command before constructing the master node."
                end

                nretry = 0
                resp = false
                while resp == false && nretry < @retry
                  resp = s.set_role(hostname, port, role, balance, partition)
                  if resp
                    info "started constructing the master node..."
                  else
                    nretry += 1
                    info "waiting #{nretry} sec..."
                    sleep nretry
                    info "retrying..."
                  end
                end
                if resp
                  state = wait_for_master_construction(s, nodekey, @timeout)
                  if state == 'ready' && @activate
                    unless @force
                      node = s.stats_nodes[nodekey]
                      STDERR.print "changing node's state (node=#{ipaddr}:#{port}, state=#{node['state']} -> active) (y/n): "
                      exec = interruptible {
                        (gets.chomp.upcase == "Y")
                      }
                    end
                    if exec
                      begin
                        resp = s.set_state(hostname, port, 'active')
                        unless resp
                          error "failed to activate #{nodekey}"
                          status = S_NG
                        end
                      rescue Timeout::Error
                        error "failed to activate #{nodekey} (timeout)"
                        status = S_NG
                      end
                    end
                  end
                else
                  error "failed to change the state."
                  status = S_NG
                end
              end
            end

            break if status == S_NG
            STDOUT.puts string_of_nodelist(s.stats_nodes, hosts.map {|x| "#{x[0]}:#{x[1]}"})
          end

          status
        end # execute()
      end
    end
  end
end
