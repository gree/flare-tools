# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'timeout'
require 'flare/net/connection'
require 'flare/util/logging'
require 'flare/util/constant'

module Flare
  module Tools
    class Stats
      include Flare::Util::Logging
      include Flare::Util::Constant

      def self.open(host, port, tout = DefaultTimeout, &block)
        stats = self.new(host, port, tout)
        return stats if block.nil?
        return block.call(stats)
      ensure
        stats.close unless stats.nil? # this might raise IOError
      end

      def initialize(host, port, tout)
        @tout = tout
        timeout(tout) do
          @conn = Flare::Net::Connection.new(host, port)
        end
      rescue Errno::ECONNREFUSED
        debug "Connection refused. server=[#{@conn}]"
        raise
      rescue TimeoutError
        debug "Connection timeout. server=[#{@conn}]"
        raise
      rescue SocketError
        debug "Connection error. server=[#{host}:#{port}]"
        raise
      end

      def host
        @conn.host
      end

      def port
        @conn.port
      end

      def request(cmd, *args)
        @conn.reconnect if @conn.closed?
        debug "Enter the command server. server=[#{@conn}] command=[#{cmd} #{args.join(' ')}]"
        response = nil
        timeout(@tout) do
          @conn.send(cmd, *args)
          response = @conn.recv
        end
        response
      rescue TimeoutError => e
        error "Connection timeout. server=[#{@conn}] command=[#{cmd} #{args.join(' ')}]"
        raise e
      end

      @@parsers = {}

      def self.defcmd(method_symbol, command_template, &block)
        @@parsers[method_symbol] = block
        self.class_eval %{
          def #{method_symbol.to_s}(*args)
            cmd = "#{command_template}"
            cmd = cmd % args if args.size > 0
            resp = request(cmd)
            if resp then @@parsers[:#{method_symbol.to_s}].call(resp) else false end
          end
        }
      
      end

      def close()
        quit
        @conn.close
      end

      defcmd :stats_nodes, 'stats nodes' do |resp|
        result = {}
        resp.gsub(/STAT /, '').split("\r\n").each do |x|
          ip, port, stat = x.split(":", 3)
          key, val = stat.split(" ")
          result["#{ip}:#{port}"] = {} if result["#{ip}:#{port}"].nil?
          result["#{ip}:#{port}"]['port'] = port
          result["#{ip}:#{port}"][key] = val
        end
        result
      end

      defcmd :stats, 'stats' do |resp|
        result = {}
        resp.gsub(/STAT /, '').split("\r\n").each do |x|
          key, val = x.split(" ", 2)
          result[key] = val
        end
        result
      end

      def stats_threads_by_peer
        result = {}
        stats_threads.each do |thread_id, stat|
          k = stat['peer']
          result[k] = {} if result[k].nil?
          result[k]['thread_id'] = thread_id
          result[k].merge!(stat)
        end
        result
      end

      def stats_threads
        stats_threads_
      end

      defcmd :stats_threads_, 'stats threads' do |resp|
        threads = {}
        resp.gsub(/STAT /, '').split("\r\n").each do |x|
          thread_id, stat = x.split(":", 2)
          key, val = stat.split(" ")
          threads[thread_id] = {} unless threads.has_key?(thread_id)
          threads[thread_id][key] = val
        end
        threads
      end

      defcmd :ping, 'ping' do |resp|
        true if resp
      end

      defcmd :quit, 'quit' do |resp|
        true
      end

    end
  end
end
