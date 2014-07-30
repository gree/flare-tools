# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'thread'
require 'flare/tools/index_server'
require 'flare/tools/cli/sub_command'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/tools/cli/index_server_config'

module Flare
  module Tools
    module Cli

      class Summary < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Logging
        include Flare::Tools::Common
        include Flare::Tools::Cli::IndexServerConfig

        myname :summary
        desc   "show the summary of a flare cluster."
        usage  "summary [hostname:port] ..."

        HeaderConfig = [ ['%-30.30s', '#cluster'],
                         ['%6s',      'part'],
                         ['%6s',      'node'],
                         ['%7s',      'master'],
                         ['%6s',      'slave'],
                         ['%16s',     'size'],
                         ['%13s',    'items'] ]

        def setup
          super
          set_option_index_server
        end

        def initialize
          super
        end

        def execute(config, args)
          parse_index_server(config, args)
          nodes = {}
          threads = {}
          header = HeaderConfig

          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes
            unless nodes
              error "Invalid index server."
              return S_NG
            end
            nodes = nodes.sort_by{|key,val| [val['partition'].to_i, val['role'], key]}
          end

          name = if config[:cluster].nil? then
                   "#{config[:index_server_hostname]}:#{config[:index_server_port]}"
                 else
                   config[:cluster]
                 end

          total_bytes = 0
          total_parts = 0
          total_nodes = 0
          total_items = 0
          total_masters = 0
          total_slaves = 0

          nodes.each do |hostname_port,data|
            hostname, port = hostname_port.split(":", 2)
            Flare::Tools::Stats.open(hostname, data['port'], config[:timeout]) do |s|
              stats = s.stats
              p = data['partition'].to_i
              total_parts = p+1 if p+1 > total_parts if data['role'] == 'master'
              total_nodes += 1
              total_masters += 1 if data['role'] == 'master'
              total_slaves += 1 if data['role'] == 'slave'
              total_bytes += stats['bytes'].to_i if data['role'] == 'master'
              total_items += stats['curr_items'].to_i if data['role'] == 'master'
            end
          end

          format = header.map {|x| x[0]}.join(@delimiter)
          label = format % header.map{|x| x[1]}.flatten
          puts label
          puts(format % [name, total_parts, total_nodes, total_masters, total_slaves, total_bytes, total_items])

          S_OK
        end

      end
    end
  end
end


