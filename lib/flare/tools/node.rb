# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/stats'

# 
module Flare
  module Tools

    # == Description
    # 
    class Node < Stats
      
      def initialize(host, port, tout)
        super(host, port, tout)
      end

      # (host, port, state)
      defcmd :set_state, 'node state %s %s %s\r\n' do |resp|
        resp
      end

      defcmd :flush_all, 'flush_all\r\n' do |resp|
        resp
      end

      def set(k, v)
        set_(k.chomp, 0, 0, v.size, v)
      end

      def set_noreply(k, v)
        set_noreply_(k.chomp, 0, 0, v.size, v)
      end

      def delete(k)
        delete_(k.chomp)
      end

      def delete_noreply(k)
        delete_noreply_(k.chomp)
      end

      def get(k)
        get_(k)
      end

      def incr(k, v)
        incr_(k, v.to_s)
      end

      def incr_noreply(k, v)
        incr_noreply(k, v.to_s)
      end

      def decr(k, v)
        decr_(k, v.to_s)
      end

      def decr_noreply(k, v)
        decr_noreply_(k, v.to_s)
      end

      defcmd_noreply :set_noreply_, 'set %s %d %d %d\r\n%s\r\n'
      defcmd :set_, 'set %s %d %d %d\r\n%s\r\n' do |resp|
        resp
      end

      defcmd_noreply :delete_, 'delete %s\r\n'
      defcmd :delete_, 'delete %s\r\n' do |resp|
        resp
      end

      defcmd :get_, 'get %s\r\n' do |resp|
        header, content = resp.split("\r\n", 2)
        sig, key, f, len = header.split(" ")
        content[0...len.to_i]
      end

      defcmd_oneline_noreply :incr_noreply, 'incr %s %s\r\n'
      defcmd_oneline :incr_, 'incr %s %s\r\n' do |resp|
        resp.chomp!
        resp
      end

      defcmd_oneline_noreply :decr_noreply_, 'decr %s %s\r\n'
      defcmd_oneline :decr_, 'decr %s %s\r\n' do |resp|
        resp.chomp!
        resp
      end

    end
  end
end
