# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/util/conf'

module Flare
  module Util
    class FlaredConf < Flare::Util::Conf
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

    end
  end
end

