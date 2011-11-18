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

      def get(k)
        get_(k)
      end

      defcmd :set_, 'set %s %d %d %d\r\n%s\r\n' do |resp|
        resp
      end

      defcmd :get_, 'get %s\r\n' do |resp|
        header, content = resp.split("\r\n", 2)
        sig, key, f, len = header.split(" ")
        content[0...len.to_i]
      end

    end
  end
end
