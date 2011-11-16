# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'rubygems'
require 'flare/tools/node'

module Flare
  module Test
    class Node
      def initialize(hostname_port)
        @hostname_port = hostname_port
        @hostname, @port = hostname_port.split(':')
      end

      def open(&block)
        ret = nil
        node = Flare::Tools::Node.open(@hostname, @port)
        if block.nil?
          ret = node
        else
          begin
            ret = block.call(node)
          rescue => e
            node.close
            raise e
          end
        end
        ret
      end

      attr_reader :hostname, :port, :hostname_port
    end
  end
end
