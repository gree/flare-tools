# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
    class Logger
      Info = :info
      Warn = :warn
      Trace = :trace
      Error = :error
      Debug = :debug

      def initialize
        
      end

      def log(type, msg)
        return if type == Debug && (defined? $DEBUG && $DEBUG)
        if type == Error
          puts "\033[31m[ERROR]\033[m #{msg}"
        else
          puts "[#{type.to_s.upcase}] #{msg}"
        end
      end
    end

    module Logging
      @@logger = Logger.new

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
