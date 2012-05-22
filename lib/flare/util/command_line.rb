# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'optparse'
require 'flare/util/logging'

# 
module Flare
  module Util

    # == Description
    # CommandLine is a mix-in module for the top level.
    # 
    #  require 'flare/util/command_line'
    #  
    #  option do |opt|
    #    ...
    #  end
    #  
    #  setup do |opt|
    #    ...
    #  end
    #  
    #  execute do |args|
    #    ...
    #  end
    module CommandLine
      @@option = OptionParser.new
      S_OK = 0
      S_NG = 1

      def option(&block)
        block.call(@@option)
      end
      
      def setup(&block)
        block.call(@@option)
        begin
          @@option.parse!(ARGV)
        rescue OptionParser::ParseError => err
          puts err.message
          puts @@option.to_s
          exit S_NG
        end
      end

      def execute(&block)
        status = S_OK
        if block
          args = ARGV.dup
          ARGV.clear
          status = block.call(args)
        end
        status
      rescue => e
        level = 1
        Logging.logger.error(e.to_s)
        e.backtrace.each do |line|
          Logging.logger.error("  %3s: %s" % [level, line])
          level += 1
        end
        raise e if $DEBUG
        S_NG
      end

    end
  end
end

extend Flare::Util::CommandLine

option do |opt|
  opt.on('-h',        '--help',     "show this message") {puts opt.help; exit 1}
  opt.on(             '--debug',    "enable debug mode") {$DEBUG = true}
  opt.on(             '--warn',     "turn on warnings") {$-w = true}
end

