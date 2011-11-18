# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'timeout'
require 'socket'
require 'flare/util'
require 'flare/util/logging'
require 'flare/util/result'

# 
module Flare
  module Net

    # == Description
    # 
    class Connection
      include Flare::Util::Logging
      include Flare::Util::Result

      def initialize(host, port)
        @host = host
        @port = port
        @socket = TCPSocket.open(host, port)
      end

      attr_reader :host, :port

      def close
        @socket.close
      end

      def closed?
        @socket.closed?
      end

      def reconnect
        if @socket.closed?
          @socket = nil
          @socket = TCPSocket.open(@host, @port)
        end
        @socket
      end

      def send(cmd, *args)
        cmd += "\r\n" unless /\n$/ =~ cmd
        cmd += " "+args.join(" ") if args.size > 0
        # trace "send. server=[#{self}] cmd=[#{cmd}]"
        @socket.write cmd
      end

      def recv
        # trace "recv. server=[#{self}]"
        resp = ""
        crlf = "\r\n"
        while x = @socket.gets
          # trace "recv. [#{x}]"
          ans = x.chomp.split(' ', 2)
          ans = if ans.empty? then '' else ans[0] end
          case ans
          when string_of_result(Ok), string_of_result(End), string_of_result(Stored)
            break
          when string_of_result(Error), string_of_result(ServerError), string_of_result(ClientError)
            warn "Failed command. server=[#{self}] result=[#{x.chomp}]"
            resp = false
            break
          else
            resp += x
          end
        end
        # trace "exit recv. [#{resp}]"
        resp
      end

      def to_s
        "#{@host}:#{@port}"
      end

    end
  end
end
