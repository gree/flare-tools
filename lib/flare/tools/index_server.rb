# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

require 'flare/tools/stats'

# 
module Flare
  module Tools

    # == Description
    # 
    class IndexServer < Stats

      def set_role(host, port, role, balance, partition)
        set_role_(host, port, role, balance, partition)
      end
      defcmd :set_role_, 'node role %s %d %s %d %d\r\n' do |resp|
        resp
      end

      def set_state(host, port, state)
        set_state_(host, port, state)
      end
      defcmd :set_state_, 'node state %s %s %s\r\n' do |resp|
        resp
      end

      def node_remove(host, port)
        node_remove_(host, port)
      end
      defcmd :node_remove_, 'node remove %s %s\r\n' do |resp|
        resp
      end

      def meta()
        meta_()
      end
      defcmd :meta_, 'meta\r\n' do |resp|
        result = {}
        resp.gsub(/META /, '').split("\r\n").each do |x|
          key, val = x.split(" ", 2)
          result[key] = val
        end
        result
      end

    end
  end
end
