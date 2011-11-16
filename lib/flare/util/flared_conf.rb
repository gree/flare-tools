# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
    class FlaredConf
      DefaultConf = {
        'data-dir' => "/tmp",
        'index-server-name' => "localhost",
        'index-server-port' => "12120",
        'log-facility' => "local1",
        'max-connection' => "256",
        'mutex-slot' => "32",
        'proxy-concurrency' => "2",
        'server-name' => "localhost",
        'server-port' => "12121",
        'storage-type' => "tch",
        'thread-pool-size' => "16",
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

