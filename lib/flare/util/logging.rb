# -*- coding: utf-8; -*-

require 'flare/util/logger'

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    #
    # == Description
    # Logging is a mix-in module for logging.
    module Logging
      @@logger = Flare::Util::Logger.new

      def self.set_logger(logger)
        @@logger = logger
      end
      
      def self.logger
        @@logger
      end

      def info(msg)
        log Logger::Info, msg
      end

      def warn(msg)
        log Logger::Warn, msg
      end

      def trace(msg)
        log Logger::Trace, msg
      end

      def error(msg)
        log Logger::Error, msg
      end

      def debug(msg)
        log Logger::Debug, msg
      end

      def log(type, msg)
        @@logger.log type, msg
      end
      
    end
  end
end
