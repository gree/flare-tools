# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

require 'rubygems'
require 'flare/util/logger'

module Flare
  module Util
    module Logging
    end
  end
end

begin
  gem 'log4r'
  require 'flare/util/log4r_logger'
  Flare::Util::Logging::Logger = Flare::Util::Log4rLogger
rescue LoadError
  require 'flare/util/default_logger'
  Flare::Util::Logging::Logger = Flare::Util::DefaultLogger
end

# 
module Flare
  module Util

    # == Description
    # Logging is a mix-in module for logging.
    module Logging
      @@logger = nil
      
      def self.set_logger(logger = nil)
        @@logger = Logger.new(logger)
      end
      
      def self.logger
        @@logger
      end

      def info(msg)
        Logging.set_logger if @@logger.nil?
        @@logger.info(msg)
      end

      def warn(msg)
        Logging.set_logger if @@logger.nil?
        @@logger.warn(msg)
      end

      def trace(msg)
        Logging.set_logger if @@logger.nil?
        @@logger.debug(msg)
      end

      def error(msg)
        Logging.set_logger if @@logger.nil?
        @@logger.error(msg)
      end

      def fatal(msg)
        Logging.set_logger if @@logger.nil?
        @@logger.fatal(msg)
      end

      def debug(msg)
        Logging.set_logger if @@logger.nil?
        @@logger.debug(msg)
      end

      # This hides Kernel's puts()
      def puts(*args)
        Logging.set_logger if @@logger.nil?
        return Kernel.puts(*args) if @@logger.console?
        for msg in args
          info(msg)
        end
        nil
      end

    end
  end
end
