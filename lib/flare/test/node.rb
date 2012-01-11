# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'rubygems'
require 'flare/tools/node'

# 
module Flare
  module Test

    # == Description
    #
    class Node
      def initialize(hostname_port, pid)
        @hostname_port = hostname_port
        @hostname, @port = hostname_port.split(':')
        @pid = pid
        @alive = true
      end

      def open(&block)
        return nil unless @alive
        node = Flare::Tools::Node.open(@hostname, @port)
        return node if block.nil?
        ret = nil
        begin
          ret = block.call(node)
        rescue => e
          node.close
          raise e
        end
        ret
      end

      def stop
        Process.kill :STOP, @pid
      end

      def cont
        Process.kill :CONT, @pid
      end

      def terminate
        puts "killing... #{@pid}"
        begin
          timeout(10) do
            Process.kill :TERM, @pid
            Process.waitpid @pid
          end
        rescue TimeoutError => e
          Process.kill :KILL, @pid
          Process.waitpid @pid
        end
        @alive = false
      end

      attr_reader :hostname, :port, :hostname_port
    end
  end
end
