# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/util/logger'
require 'log4r'
require 'log4r/configurator'

# 
module Flare
  module Util

    # == Description
    # Log4rLogger is a custom logging class for log4r
    class Log4rLogger < Logger
      @@formatter = Log4r::PatternFormatter.new(
                                                :pattern => "%d %C[%l]: %M",
                                                :date_format => "%Y/%m/%d %H:%M:%S"
                                                )
      @@console_formatter = Log4r::PatternFormatter.new(
                                                        :pattern => "%M",
                                                        :date_format => "%Y/%m/%d %H:%M:%S"
                                                        )
      def initialize(logger)
        if logger.nil?
          outputter = Log4r::StdoutOutputter.new(
                                                 "console",
                                                 :formatter => @@console_formatter
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
        @logger = logger
      end

      def info(msg)
        @logger.info(msg)
      end

      def warn(msg)
        @logger.warn(msg)
      end

      def trace(msg)
        @logger.debug(msg)

      end

      def error(msg)
        @logger.error(msg)
      end

      def fatal(msg)
        @logger.fatal(msg)
      end

      def debug(msg)
        @logger.debug(msg)
      end
    end

  end
end
