# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require "flare/util/logging"

# 
module Flare
  module Util

    # == Description
    # 
    class Bwlimit
      include Flare::Util::Logging

      DefaultBandwidth = 1024*1024 # 1Mbps
      Ki = 1024
      Mi = 1024*Ki
      Gi = 1024*Mi
      Bit = 1
      Byte = 8

      def initialize(bwlimit)
        @bps = Bwlimit.bps(bwlimit)
        @basetime = @starttime = Time.now
        @duration = 1.0
        @received_size = 0
        @history = []
        @minwait = 0.01
        @speed = 0
        @sentbytes = 0
      end

      def limit=(bwlimit)
        @bps = Bwlimit.bps(bwlimit)
      end

      def bps
        @bps
      end

      def start
        @basetime = @starttime = Time.now
      end
      
      def iterate(&block)
        block.call
      end

      def inc(bytes)
        @received_size += bytes
        @sentbytes += bytes
      end

      def time_to_wait(now = Time.now)
        waitsec = 0
        limit = @bps/Byte
        receivable_size = (now-@basetime)*limit
        if @received_size > receivable_size
          debug "received_size=#{@received_size} receivable_size=#{receivable_size}"
          waitsec = ((@received_size-receivable_size).to_f/limit)
        end
        unless waitsec > 0
          waitsec = @minwait if waitsec < @minwait
        end
        waitsec
      end

      def pasttime(now = Time.now)
        now-@basetime
      end

      def wait
        waitsec = 0
        if @bps > 0
          now = Time.now
          sleep time_to_wait(now)
          diff = pasttime(now)
          if diff > @duration
            @speed = @received_size*Byte/diff
            debug "#{@speed} bps"
            @received_size = 0
            @basetime = now
            @history << {:time => now-@starttime, :speed => @speed}
          end
        end
        waitsec
      end

      def history
        @history.dup
      end

      def speed
        @speed
      end

      def sentbytes
        @sentbytes
      end
      
      def self.bps(bw)
        case bw
        when /^(\d+)$/
          $1.to_i*Bit
        when /^(\d+)B$/
          $1.to_i*Byte
        when /^(\d+)kb$/
          $1.to_i*Ki*Bit
        when /^(\d+)kB$/
          $1.to_i*Ki*Byte
        when /^(\d+)Mb$/
          $1.to_i*Mi*Bit
        when /^(\d+)MB$/
          $1.to_i*Mi*Byte
        when /^(\d+)Gb$/
          $1.to_i*Gi*Bit
        when /^(\d+)GB$/
          $1.to_i*Gi*Byte
        else
          bw.to_i
        end
      end

    end

  end
end


