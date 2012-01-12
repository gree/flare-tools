# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'timeout'
require 'flare/net/connection'
require 'flare/util/logging'
require 'flare/util/constant'
require 'flare/util/result'

# 
module Flare
  module Tools

    # == Description
    # 
    class Client
      include Flare::Util::Logging
      extend Flare::Util::Logging
      include Flare::Util::Constant
      include Flare::Util::Result

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

      def hostname
        @conn.host
      end

      def port
        @conn.port
      end

      def request(cmd, parser, processor, *args)
        # info "request(#{cmd}, #{noreply})"
        @conn.reconnect if @conn.closed?
        debug "Enter the command server. server=[#{@conn}] command=[#{cmd} #{args.join(' ')}]"
        response = nil
        timeout(@tout) do
          @conn.send(cmd, *args)
          response = parser.call(@conn, processor)
        end
        response
      rescue TimeoutError => e
        error "Connection timeout. server=[#{@conn}] command=[#{cmd} #{args.join(' ')}]"
        @conn.close
        raise e
      end

      def sent_size
        @conn.sent_size
      end

      def sent_size=(v)
        @conn.sent_size = v
      end

      def received_size
        @conn.received_size
      end

      def received_size=(v)
        @conn.received_size = v
      end

      def close()
        quit
        @conn.close
      end

      @@processors = {}
      @@parsers = {}

      def self.defcmd_generic(method_symbol, command_template, parser, *options, &default_processor)
        @@parsers[method_symbol] = parser
        @@processors[method_symbol] = default_processor
        optary = options.map {|x| '"'+x+'"'}.join(',')
        self.class_eval %{
          def #{method_symbol.to_s}(*args, &processor)
            options = [#{optary}]
            cmd = "#{command_template}"
            cmd = cmd % args if args.size > 0
            processor = @@processors[:#{method_symbol}] if processor.nil?
            request(cmd, @@parsers[:#{method_symbol}], processor, *options)
          end
        }
      end

      def self.defcmd(method_symbol, command_template, &default_processor)
        parser = Proc.new do |conn, processor|
          resp = ""
          answers = [Ok, End, Stored, Deleted, NotFound].map {|x| Flare::Util::Result.string_of_result(x)}
          errors = [Error, ServerError, ClientError].map {|x| Flare::Util::Result.string_of_result(x)}
          while x = conn.getline
            ans = x.chomp.split(' ', 2)
            ans = if ans.empty? then '' else ans[0] end
            case ans
            when *answers
              break
            when *errors
              warn "Failed command. server=[#{self}] sent=[#{conn.last_sent}] result=[#{x.chomp}]"
              resp = false
              break
            else
              resp += x
            end
          end
          if resp 
            if processor.nil?
              resp
            else
              processor.call(resp)
            end
          else
            false
          end
        end
        defcmd_generic(method_symbol, command_template, parser, &default_processor)
      end

      def self.defcmd_noreply(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          processor.call() unless processor.nil?
        }
        defcmd_generic(method_symbol, command_template, parser, "noreply", &default_processor)
      end
 
      def self.defcmd_oneline(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          line = conn.getline
          if processor.nil?
            line
          else
            processor.call(line)
          end
        }
        defcmd_generic(method_symbol, command_template, parser, &default_processor)
      end

      def self.defcmd_key(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          rets = []
          while true
            line = conn.getline
            elems = line.split(' ')
            if elems[0] == "KEY"
              unless processor.nil?
                r = processor.call(elems[1])
                rets << r if r
              end
            elsif elems[0] == "END"
              return rets[0] if rets.size == 1
              return rets
            else
              info "error \"#{line.chomp}\""
              return false
            end
          end
        }
        defcmd_generic(method_symbol, command_template, parser, &default_processor)
      end

      def self.defcmd_value(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          rets = []
          while true
            line = conn.getline
            elems = line.split(' ')
            if elems[0] == "VALUE"
              key, flag, len, version, expire = elems[1], elems[2].to_i, elems[3].to_i, elems[4], elems[5]
              data = conn.read(len)
              unless processor.nil?
                r = processor.call(data, key, flag, len, version, expire)
                rets << r if r
              end
              conn.getline # skip
            elsif elems[0] == "END"
              return rets[0] if rets.size == 1
              return rets
            else
              info "error \"#{line.chomp}\""
              return false
            end
          end
        }
        defcmd_generic(method_symbol, command_template, parser, &default_processor)
      end

    end
  end
end
