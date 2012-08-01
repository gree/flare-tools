# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'thread'
require 'flare/tools/index_server'
require 'flare/tools/cli/sub_command'
require 'flare/tools/common'
require 'flare/util/conversion'

# 
module Flare
  module Tools
    module Cli

      # == Description
      #
      class Summary < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Logging
        include Flare::Tools::Common
        
        myname :summary
        desc   "show the summary of a flare cluster."
        usage  "summary [hostname:port] ..."

        HeaderConfig = [ ['%-30.30s', '#cluster'],
                         ['%6s',      'part'],
                         ['%6s',      'node'],
                         ['%16s',     'size'],
                         ['%13s',    'items'] ]

        def setup(opt)
        end

        def initialize
          super
        end
  
        def execute(config, *args)
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
          total_parts = {}
          total_nodes = 0
          total_items = 0

          nodes.each do |hostname_port,data|
            hostname, port = hostname_port.split(":", 2)
            Flare::Tools::Stats.open(hostname, data['port'], config[:timeout]) do |s|
              stats = s.stats
              total_bytes += stats['bytes'].to_i
              total_parts[stats['partitions']] = 0 unless total_parts.has_key?(stats['partitions'])
              total_parts[stats['partitions']] += 1
              total_nodes += 1
              total_items += stats['curr_items'].to_i
            end
          end

          format = header.map {|x| x[0]}.join(@delimiter)
          label = format % header.map{|x| x[1]}.flatten
          puts label
          puts(format % [name, total_parts, total_nodes, total_bytes, total_items])
          
          S_OK
        end

      end
    end
  end
end


