# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

require 'flare/tools/common'
require 'flare/tools/cli/sub_command'
require 'flare/tools/cli/index_server_config'
require 'flare/cli/parse_host_port_pairs'
require 'flare/cli/ask_node_remove'
require 'flare/operation/node_remove'

module Flare; end
module Flare::Tools; end
module Flare::Tools::Cli; end

class Flare::Tools::Cli::Remove < Flare::Tools::Cli::SubCommand
  include Flare::Tools::Common
  include Flare::Tools::Cli::IndexServerConfig
  include Flare::Cli::ParseHostPortPairs
  include Flare::Cli::AskNodeRemove
  include Flare::Operation::NodeRemove

  myname :remove
  desc   "remove a downed node."
  usage  "remove [hostname:port] ..."

  def setup
    super
    set_option_index_server
    set_option_dry_run
    set_option_force
    @optp.on('--retry=COUNT', "retry count(default:#{@retry})") {|v| @retry = v.to_i }
  end

  def initialize
    super
    @retry = 0
  end

  def execute(config, args)
    parse_index_server(config, args)
    nodes = parse_host_port_pairs(args)
    unless nodes
      return S_NG
    end

    Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], @timeout) do |s|
      cluster = fetch_cluster(s)

      nodes.each do |node|
        node_stat = cluster.node_stat(node.nodekey)

        unless node_stat
          error "node not found in cluster. (node=#{node})"
          next
        end

        # check status downed & proxy
        unless node_can_remove_safely?(node_stat)
          error "node should role=proxy and state=down. (node=#{node} role=#{node_stat.role} state=#{node_stat.state})"
          return S_NG
        end

        # ask really remove or not
        unless @force || ask_node_remove(node, node_stat)
          return S_NG
        end

        succeeded = node_remove(s, node, @retry, @dry_run)
        unless succeeded
          error "node remove failed. (node=#{node})"
          return S_NG
        end
      end

      # puts node list after nodes removed
      puts ""
      puts string_of_nodelist(s.stats_nodes)

      return S_OK
    end
  end
end
