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
        @sent = ""
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
        lines = cmd.split("\r\n")
        cmd = lines.shift
        cmd += " "+args.join(" ") if args.size > 0
        cmd += "\r\n"
        for line in lines
          cmd += line+"\r\n"
        end
        # trace "send. server=[#{self}] cmd=[#{cmd}]"
        @socket.write cmd
        @sent = cmd
      end

      def recv(oneline = false)
        # trace "recv. server=[#{self}]"
        resp = ""
        crlf = "\r\n"
        while x = @socket.gets
          # trace "recv. [#{x}]"
          ans = x.chomp.split(' ', 2)
          ans = if ans.empty? then '' else ans[0] end
          case ans
          when string_of_result(Ok), string_of_result(End), string_of_result(Stored), string_of_result(Deleted), string_of_result(NotFound)
            break
          when string_of_result(Error), string_of_result(ServerError), string_of_result(ClientError)
            warn "Failed command. server=[#{self}] sent=[#{@sent}] result=[#{x.chomp}]"
            resp = false
            break
          else
            resp += x
            break if oneline
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
