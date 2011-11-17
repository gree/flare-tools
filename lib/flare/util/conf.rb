# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
    class Conf

      def initialize(config)
        @config = {}
        @config = config unless config.nil?
      end

      def to_s
        conf = ""
        @config.each do |k,v|
          conf += "#{k} = #{v}\n"
        end
        conf
      end

      def each(&block)
        @config.each do |k,v|
          block.call(k, v) if block
        end
      end

      def server_name
        @config['server-name']
      end

      def server_port
        @config['server-port']
      end

      def hostname_port
        "#{server_name}:#{server_port}"
      end

      def data_dir
        @config['data-dir']
      end
      
    end
  end
end
