# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
    class FlareiConf
      DefaultConf = {
        'data-dir' => "/tmp",
        'log-facility' => "local0",
        'max-connection' => 256,
        'monitor-threshold' => 3,
        'monitor-interval' => 1,
        'server-name' => "localhost",
        'server-port' => 12120,
        'thread-pool-size' => 8,
      }
      
      def initialize(config)
        @config = DefaultConf.merge(config)
      end

      def to_s
        conf = ""
        @config.each do |k,v|
          conf += "#{k} = #{v}\n"
        end
        conf
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
      
    end
  end
end

