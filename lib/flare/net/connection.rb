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
        @sent_size = 0
        @received_size = 0
      end

      attr_reader :host, :port
      attr_accessor :sent_size, :received_size

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

      def send(cmd)
        cmd.chomp!
        cmd += "\r\n"
        # trace "send. server=[#{self}] cmd=[#{cmd}]"
        @sent_size = cmd.size
        @socket.write cmd
        @sent = cmd
      end

      def last_sent
        @sent
      end

      def getline
        ret = @socket.gets
        @received_size += ret.size unless ret.nil?
        ret
      end

      def read(length = nil)
        ret = @socket.read(length)
        @received_size += ret.size unless ret.nil?
        ret
      end

      def to_s
        "#{@host}:#{@port}"
      end

    end
  end
end
