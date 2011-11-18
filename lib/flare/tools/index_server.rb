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
    class IndexServer < Stats

      def initialize(host, port, tout = DefaultTimeout)
        super(host, port, tout)
      end

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

    end
  end
end
