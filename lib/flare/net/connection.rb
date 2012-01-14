# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'timeout'
require 'socket'
require 'flare/util'
require 'flare/util/logging'
require 'flare/util/result'
require 'flare/util/bwlimit'

# 
module Flare
  module Net

    # == Description
    # 
    class Connection
      include Flare::Util::Logging
      include Flare::Util::Result

      def initialize(host, port, uplink_limit = nil, downlink_limit = nil)
        @host = host
        @port = port
        @socket = TCPSocket.open(host, port)
        @last_sent = ""
        @sent_size = 0
        @received_size = 0
        @uplink_limit = Flare::Util::Bwlimit.new(uplink_limit)
        @downlink_limit = Flare::Util::Bwlimit.new(downlink_limit)
      end

      attr_reader :host, :port
      attr_reader :sent_size, :received_size

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
        # trace "send. server=[#{self}] cmd=[#{cmd}]"
        size = cmd.size
        @sent_size += size
        @socket.write cmd
        @last_sent = cmd
        @uplink_limit.inc size
        @uplink_limit.wait
      end

      def last_sent
        @last_sent
      end

      def getline
        ret = @socket.gets
        unless ret.nil?
          size = ret.size
          @received_size += size
          @downlink_limit.inc size
          @downlink_limit.wait
        end
        ret
      end

      def read(length = nil)
        ret = @socket.read(length)
        unless ret.nil?
          size = ret.size
          @received_size += size
          @downlink_limit.inc size
          @downlink_limit.wait
        end
        ret
      end

      def to_s
        "#{@host}:#{@port}"
      end

    end
  end
end
