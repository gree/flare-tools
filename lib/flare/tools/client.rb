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

      def self.open(host, port, tout = DefaultTimeout, uplink_limit = DefalutBwlimit, downlink_limit = DefalutBwlimit, &block)
        stats = self.new(host, port, tout, uplink_limit, downlink_limit)
        return stats if block.nil?
        return block.call(stats)
      ensure
        unless stats.nil? # this might raise IOError
          stats.close
        end
      end

      def initialize(host, port, tout = DefaultTimeout, uplink_limit = DefalutBwlimit, downlink_limit = DefalutBwlimit)
        @tout = tout
        timeout(tout) do
          @conn = Flare::Net::Connection.new(host, port, uplink_limit, downlink_limit)
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

      def request(cmd, parser, processor, tout = @tout)
        # info "request(#{cmd}, #{noreply})"
        @conn.reconnect if @conn.closed?
        debug "Enter the command server. server=[#{@conn}] command=[#{cmd}}]"
        response = nil
        cmd.chomp!
        cmd += "\r\n"
        timeout(tout) do
          @conn.send(cmd)
          response = parser.call(@conn, processor)
        end
        response
      rescue TimeoutError => e
        error "Connection timeout. server=[#{@conn}] command=[#{cmd}}]"
        @conn.close
        raise e
      end

      def sent_size
        @conn.sent_size
      end

      def received_size
        @conn.received_size
      end

      def close()
        begin
          timeout(1) { quit }
        rescue Timeout::Error => e
        end
        @conn.close
      end

      @@processors = {}
      @@parsers = {}

      def self.defcmd_generic(method_symbol, command_template, parser, timeout, &default_processor)
        @@parsers[method_symbol] = parser
        @@processors[method_symbol] = default_processor || proc { false }
        timeout_expr = if timeout then "@tout" else "nil" end
        self.class_eval %{
          def #{method_symbol.to_s}(*args, &processor)
            cmd = "#{command_template}"
            cmd = cmd % args if args.size > 0
            processor = @@processors[:#{method_symbol}] if processor.nil?
            request(cmd, @@parsers[:#{method_symbol}], processor, #{timeout_expr})
          end
        }
      end

      def self.defcmd(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
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
          return processor.call(resp) if resp 
          return false
        }
        defcmd_generic(method_symbol, command_template, parser, true, &default_processor)
      end

      def self.defcmd_noreply(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          return processor.call()
        }
        defcmd_generic(method_symbol, command_template, parser, true, &default_processor)
      end
 
      def self.defcmd_oneline(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          processor.call(conn.getline)
        }
        defcmd_generic(method_symbol, command_template, parser, true, &default_processor)
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
              return rets
            else
              info "error \"#{line.chomp}\""
              return false
            end
          end
        }
        defcmd_generic(method_symbol, command_template, parser, false, &default_processor)
      end

      def self.defcmd_value(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          rets = []
          while true
            line = conn.getline
            elems = line.split(' ')
            if elems[0] == "VALUE"
              key, flag, len, version, expire = elems[1], elems[2].to_i, elems[3].to_i, elems[4].to_i, elems[5].to_i
              data = conn.read(len)
              unless processor.nil?
                r = processor.call(data, key, flag, len, version, expire)
                rets << r if r
              end
              conn.getline # skip
            elsif elems[0] == "END"
              return rets
            else
              info "error \"#{line.chomp}\""
              return false
            end
          end
        }
        defcmd_generic(method_symbol, command_template, parser, false, &default_processor)
      end

      def self.defcmd_listelement(method_symbol, command_template, &default_processor)
        parser = lambda {|conn,processor|
          rets = []
          while true
            line = conn.getline
            elems = line.split(' ')
            if elems[0] == "LISTELEMENT"
              key, rel, abs = elems[1], elems[2].to_i, elems[3].to_i
              flag, len, version, expire = elems[4].to_i, elems[5].to_i, elems[6], elems[7]
              data = conn.read(len)
              unless processor.nil?
                r = processor.call(data, key, rel, abs, flag, len, version, expire)
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
        defcmd_generic(method_symbol, command_template, parser, false, &default_processor)
      end

    end
  end
end
