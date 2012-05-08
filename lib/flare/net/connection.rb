# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

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
        @socket.close unless @socket.closed?
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
        if $DEBUG
          puts "send. server=[#{self}] cmd=[#{cmd.chomp}]"
        end
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
        return nil if ret.nil?
        if $DEBUG
          puts ret.chomp
        end
        size = ret.size
        @received_size += size
        @downlink_limit.inc size
        @downlink_limit.wait
        ret
      end

      def read(length = nil)
        ret = @socket.read(length)
        return nil if ret.nil?
        size = ret.size
        @received_size += size
        @downlink_limit.inc size
        @downlink_limit.wait
        ret
      end

      def to_s
        "#{@host}:#{@port}"
      end

    end
  end
end
