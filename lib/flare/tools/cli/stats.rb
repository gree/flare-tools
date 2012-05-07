# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
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
      class Stats < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Logging
        include Flare::Tools::Common
        
        myname :stats
        desc   "show the statistics of a flare cluster."
        usage  "stats [hostname:port] ..."

        HeaderConfig = [ ['%-25.25s', 'hostname:port'],
                         ['%6s',      'state'],
                         ['%6s',      'role'],
                         ['%9s',      'partition'],
                         ['%7s',      'balance'],
                         ['%8.8s',    'items'],
                         ['%4s',      'conn'],
                         ['%6.6s',    'behind'],
                         ['%3.3s',    'hit'],
                         ['%4.4s',    'size'],
                         ['%6.6s',    'uptime'],
                         ['%7s',      'version'] ]

        def setup(opt)
          opt.on("-q", '--qps',                "show qps")                     {@qps = true}
          opt.on("-w", '--wait=[SECOND]',      "wait time for repeat(second)") {|v| @wait = v.to_i}
          opt.on("-c", '--count=[REPEATTIME]', "repeat count")                 {|v| @count = v.to_i}
          opt.on("-d", '--delimiter=[CHAR]',   "delimiter")                    {|v| @delimiter = v}
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

        def execute(config, *args)
          nodes = {}
          threads = {}
          header = HeaderConfig.dup
          header << ['%5.5s', 'qps'] << ['%5.5s', 'qps-r'] << ['%5.5s', 'qps-w'] if @qps

          format = header.map {|x| x[0]}.join(@delimiter)
          label = format % header.map{|x| x[1]}.flatten

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
            hostname, port = hostname_port.split(":", 2)
            queue[hostname_port] = SizedQueue.new(1)
            worker_threads << Thread.new(queue[hostname_port]) do |q|
              s = nil
              while @cont
                stats_data = nil
                begin
                  s = Flare::Tools::Stats.open(hostname, data['port'], config[:timeout])
                  stats = s.stats
                  time = Time.now
                  behind = threads[hostname_port].key?('behind') ? threads[hostname_port]['behind'] : "-"
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
            end # Thread.new
          end # nodes.each

          query_prev = {} if @qps

          if @count > 1 || @qps
            interruptible {sleep 1}
          end

          s = Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout])
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
            puts label
            nodes.each do |k, n|
              stats_data = queue[k].pop
              next if (args.size > 0 && !args.include?(k))
              stats_data[:state] = n['state']
              stats_data[:role] = n['role']
              stats_data[:partition] = n['partition']
              stats_data[:balance] = n['balance']
              stats_data[:behind] = threads[k].key?('behind') ? threads[k]['behind'] : "-"
              output = [:hostname_port, :state, :role, :partition, :balance, :items,
                        :conn, :behind, :hit_rate, :size, :uptime_short, :version].map {|x| stats_data[x]}
              if @qps
                query = {}
                query[:query] = stats_data[:cmd_get].to_i+stats_data[:cmd_set].to_i
                query[:query_r] = stats_data[:cmd_get].to_i
                query[:query_w] = stats_data[:cmd_set].to_i
                query[:time] = time = stats_data[:time]
                if query_prev.has_key?(k)
                  duration = (time-query_prev[k][:time]).to_f
                  [:query, :query_r, :query_w].each do |x|
                    diff = (query[x]-query_prev[k][x]).to_f
                    qps = if diff > 0 then diff/duration else 0 end
                    output << qps
                  end
                else
                  output << 0 << 0 << 0
                end
                query_prev[k] = query.dup
              end

              puts format % output
            end
            interruptible {
              wait_for_stats
            }
          end
          s.close

          @cont = false

          queue.each do |k,q|
            q.clear
          end
          
          interruptible {
            worker_threads.each do |t|
              t.join
            end
          }
          
          S_OK
        end

        def wait_for_stats
          if @qps || @count > 1
            wait = @wait
            while wait > 0 && @cont
              sleep 1
              wait -= 1
            end
          end
        end
        
      end
    end
  end
end

