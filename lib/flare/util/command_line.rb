# -*- coding: utf-8; -*-

require 'optparse'
require 'flare/util/logging'

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    # 
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
    #  
    # Plesase note that CommandLine includes Logging module.
    module CommandLine
      include Flare::Util::Logging
      @@option = OptionParser.new

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
          exit 1
        end
      end

      def execute(&block)
        if block
          args = ARGV.dup
          ARGV.clear
          block.call(args)
        end
      rescue => e
        error e.to_s
        raise e if $DEBUG
      end

    end
  end
end

extend Flare::Util::CommandLine

option do |opt|
  opt.on('-h',        '--help',     "shows this message") {puts opt.help; exit 1}
  opt.on('-d',        '--debug',    "enables debug mode") {$DEBUG = true}
  opt.on("-w",        '--warn',     "turns on warnings") {$-w = true}
  opt.on(             '--log-file=[LOGFILE]', "outputs log to a file") {|v| Logging.set_logger(v)}
end

