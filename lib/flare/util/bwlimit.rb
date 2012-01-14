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
        @limit = Bwlimit.bps(bwlimit)
        @basetime = @starttime = Time.now
        @duration = 1.0
        @history = []
        @minwait = 0.01
        @speed = 0
        @bytes = 0
        @totalbytes = 0
        @thresh = 10*Ki
      end

      def limit=(bwlimit)
        @limit = Bwlimit.bps(bwlimit)
      end

      def limit
        @limit
      end

      def bps
        @limit
      end

      def reset
        @basetime = @starttime = Time.now
      end
      
      def inc(bytes)
        @bytes += bytes
        @totalbytes += bytes
      end

      def time_to_wait(now = Time.now)
        waitsec = 0
        limit = @limit/Byte
        allowed = (now-@basetime)*limit
        if @bytes > allowed
          waitsec = ((@bytes-allowed).to_f/limit)
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
        if @limit > 0 && @bytes > @thresh
          now = Time.now
          sleep time_to_wait(now)
          diff = pasttime(now)
          if diff > @duration
            @speed = @bytes*Byte/diff
            debug "#{@speed} bps"
            @bytes = 0
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

      def totalbytes
        @totalbytes
      end
      
      def self.bps(bw)
        return 0 if bw.nil?
        case bw
        when /^(\d+)$/
          $1.to_i*Bit
        when /^(\d+)B$/
          $1.to_i*Byte
        when /^(\d+)k$/
          $1.to_i*Ki*Bit
        when /^(\d+)kB$/
          $1.to_i*Ki*Byte
        when /^(\d+)M$/
          $1.to_i*Mi*Bit
        when /^(\d+)MB$/
          $1.to_i*Mi*Byte
        when /^(\d+)G$/
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


