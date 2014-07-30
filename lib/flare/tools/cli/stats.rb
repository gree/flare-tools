# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'thread'
require 'flare/tools/index_server'
require 'flare/tools/cli/sub_command'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/pretty_table'
require 'flare/tools/cli/index_server_config'

module Flare
  module Tools
    module Cli

      # == Description
      #
      class Stats < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Logging
        include Flare::Tools::Common
        include Flare::Util::PrettyTable
        include Flare::Tools::Cli::IndexServerConfig

        myname :stats
        desc   "show the statistics of a flare cluster."
        usage  "stats [hostname:port] ..."

        HeaderConfigs = [
          ['hostname:port', {}],
          ['state', {}],
          ['role', {}],
          ['partition', {:align => :right}],
          ['balance', {:align => :right}],
          ['items', {:align => :right}],
          ['conn', {:align => :right}],
          ['behind', {:align => :right}],
          ['hit', {:align => :right}],
          ['size', {:align => :right}],
          ['uptime', {:align => :right}],
          ['version', {:align => :right}],
        ]
        HeaderConfigQpss = [
          ['qps', {:align => :right}],
          ['qps-r', {:align => :right}],
          ['qps-w', {:align => :right}],
        ]

        def setup
          super
          set_option_index_server
          @optp.on("-q", '--qps',              "show qps")                             {|v| @qps = v}
          @optp.on("-w", '--wait=SECOND',      "specify wait time for repeat(second)") {|v| @wait = v.to_i}
          @optp.on("-c", '--count=REPEATTIME', "specify repeat count")                 {|v| @count = v.to_i}
          @optp.on("-d", '--delimiter=CHAR',   "specify delimiter")                    {|v| @delimiter = v}
        end

        def initialize
          super
          @qps = false
          @wait = 1
          @count = 1
          @cont = true
          @delimiter = ' '
        end

        def interrupt
          puts "INTERRUPTED"
          @cont = false
        end

        def execute(config, args)
          parse_index_server(config, args)
          nodes = {}
          threads = {}

          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes
            unless nodes
              error "Invalid index server."
              return S_NG
            end
            nodes = nodes.sort_by{|key,val| [val['partition'].to_i, val['role'], key]}
            threads = s.stats_threads_by_peer
          end

          worker_threads = []
          queue = {}

          nodes.each do |hostname_port,data|
            queue[hostname_port] = SizedQueue.new(1)
            worker_threads << Thread.new(queue[hostname_port]) do |q|
              enqueueing_node_stats(q, threads, config, hostname_port, data)
            end
          end

          query_prev = {} if @qps

          if @count > 1 || @qps
            interruptible {sleep 1}
          end

          s = Flare::Tools::IndexServer.open(
            @index_server_entity.host,
            @index_server_entity.port,
            config[:timeout]
          )
          unless s
            error "Couldn't connect to the index server."
            return S_NG
          end

          (0...@count).each do |i|
            nodes = s.stats_nodes
            unless nodes
              error "Invalid index server."
              exit 1
            end
            nodes = nodes.sort_by{|key,val| [val['partition'].to_i, val['role'], key]}
            threads = s.stats_threads_by_peer

            break unless @cont
            max_nodekey_length = 25
            nodes.each do |k, n|
              max_nodekey_length = k.length if k.length > max_nodekey_length
            end
            table = Table.new
            add_header_to_table(table, header_configs)
            nodes.each do |k, node|
              stats_data = queue[k].pop
              next if (args.size > 0 && !args.include?(k))
              behind = (threads.has_key?(k) || threads[k].has_key?('behind')) ? threads[k]['behind'] : "-"
              r = record(stats_data, node, behind, query_prev, k)
              add_record_to_table(table, header_configs, r)
            end
            interruptible {
              wait_for_stats
            }
            puts table.prettify
          end
          s.close

          @cont = false

          queue.each do |k,q|
            q.pop until q.empty?
          end

          interruptible {
            worker_threads.each do |t|
              t.join
            end
          }

          S_OK
        end

        private

        def wait_for_stats
          if @qps || @count > 1
            wait = @wait
            while wait > 0 && @cont
              sleep 1
              wait -= 1
            end
          end
        end

        def enqueueing_node_stats(q, threads, config, hostname_port, data)
          hostname, port = hostname_port.split(":", 2)
          s = nil
          while @cont
            stats_data = nil
            begin
              s = Flare::Tools::Stats.open(hostname, data['port'], config[:timeout])
              stats = s.stats
              time = Time.now
              behind = threads[hostname_port].has_key?('behind') ? threads[hostname_port]['behind'] : "-"
              uptime_short = short_desc_of_second(stats['uptime'])
              hit_rate = if stats.has_key?('cmd_get') && stats['cmd_get'] != "0"
                           cmd_get = stats['cmd_get'].to_f
                           get_hits = stats['get_hits'].to_f
                           (get_hits / cmd_get * 100.0).round
                         else
                           "-"
                         end
              size =  stats['bytes'] == "0" ? "-" : (stats['bytes'].to_i / 1024 / 1024 / 1024) # gigabyte
              stats_data = {
                :hostname   => hostname,
                :port       => port,
                :hostname_port => "#{hostname}:#{port}",
                :state      => data['state'],
                :role       => data['role'],
                :partition  => data['partition'] == "-1" ? "-" : data['partition'],
                :balance    => data['balance'],
                :items      => stats['curr_items'],
                :conn       => stats['curr_connections'],
                :behind     => behind,
                :hit_rate   => hit_rate,
                :size       => size,
                :uptime     => stats['uptime'],
                :uptime_short => uptime_short,
                :version    => stats['version'],
                :cmd_get    => stats['cmd_get'],
                :cmd_set    => stats['cmd_set'],
                :time       => time,
              }
            rescue Errno::ECONNREFUSED => e
            rescue => e
              begin
                s.close unless s.nil?
              rescue => close_error
                error "Socket close failed: #{close_error.inspect}"
              end
              s = nil
            end
            if stats_data.nil?
              stats_data = {
                :hostname_port => "#{hostname}:#{port}",
              }
            end
            q.push stats_data
          end
          s.close unless s.nil?
        end

        def add_header_to_table(table, header_configs)
          row = Row.new(:separator => @delimiter)
          header_configs.each do |header_config|
            row.add_column(Column.new(header_config[0]))
          end
          table.add_row(row)
        end

        def add_record_to_table(table, header_configs, record)
          row = Row.new(:separator => @delimiter)
          header_configs.each_with_index do |header_config, index|
            row.add_column(Column.new(record[index], header_config[1]))
          end
          table.add_row(row)
        end

        # You can override this method to extend stats infos.
        def record(stats_data, node, behind, query_prev, index)
          stats_data[:state] = node['state']
          stats_data[:role] = node['role']
          stats_data[:partition] = node['partition']
          stats_data[:balance] = node['balance']
          stats_data[:behind] = behind
          output = [:hostname_port, :state, :role, :partition, :balance, :items,
                    :conn, :behind, :hit_rate, :size, :uptime_short, :version].map {|x| stats_data[x]}
          if @qps
            query = {}
            query[:query] = stats_data[:cmd_get].to_i+stats_data[:cmd_set].to_i
            query[:query_r] = stats_data[:cmd_get].to_i
            query[:query_w] = stats_data[:cmd_set].to_i
            query[:time] = time = stats_data[:time]
            if query_prev.has_key?(index)
              duration = (time-query_prev[index][:time]).to_f
              [:query, :query_r, :query_w].each do |x|
                diff = (query[x]-query_prev[index][x]).to_f
                qps = if diff > 0 then diff/duration else 0 end
                output << sprintf("%.1f", qps)
              end
            else
              output << '-' << '-' << '-'
            end
            query_prev[index] = query.dup
          end
          output
        end

        # You can override this method to extend stats infos.
        def header_configs
          configs = Marshal.load(Marshal.dump(HeaderConfigs))
          configs += Marshal.load(Marshal.dump(HeaderConfigQpss)) if @qps
          configs
        end
      end
    end
  end
end

