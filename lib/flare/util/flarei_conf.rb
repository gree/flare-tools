# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

require 'flare/util/conf'

# 
module Flare
  module Util

    # 
    class FlareiConf < Flare::Util::Conf
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

    end
  end
end

