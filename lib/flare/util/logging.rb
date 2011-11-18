# -*- coding: utf-8; -*-

require 'rubygems'
require 'log4r'
require 'log4r/configurator'

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    #
    # == Description
    # Logging is a mix-in module for logging.
    module Logging
      @@logger = nil
      @@formatter = Log4r::PatternFormatter.new(
                                                :pattern => "%d %C[%l]: %M",
                                                :date_format => "%Y/%m/%d %H:%M:%S"
                                                )
      def self.set_logger(logger = nil)
        if logger.nil?
          outputter = Log4r::StdoutOutputter.new(
                                                 "console",
                                                 :formatter => @@formatter
                                                 )
          logger = Log4r::Logger.new($0)
          logger.level = Log4r::INFO
          logger.add(outputter)
        elsif logger.instance_of?(String)
          outputter = Log4r::FileOutputter.new(
                                               "file",
                                               :filename => logger,
                                               :trunc => false,
                                               :formatter => @@formatter
                                               )
          logger = Log4r::Logger.new($0)
          logger.level = Log4r::INFO
          logger.add(outputter)
        end
        @@logger = logger
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
        if @@logger.nil? || 
            @@logger.instance_of?(Log4r::StdoutOutputter) ||
            @@logger.instance_of?(Log4r::StderrOutputter)
          return Kernel.puts *args
        end
        for msg in args
          info(msg)
        end
        nil
      end

    end
  end
end
