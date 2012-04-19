# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'optparse'

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
    #  
    # Plesase note that CommandLine includes Logging module.
    module CommandLine
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

      S_OK = 0
      S_NG = 1

      def execute(&block)
        status = S_OK
        if block
          args = ARGV.dup
          ARGV.clear
          status = block.call(args)
        end
        status
      rescue => e
        error e.to_s
        raise e if $DEBUG
        S_NG
      end

    end
  end
end

extend Flare::Util::CommandLine

option do |opt|
  opt.on('-h',        '--help',     "shows this message") {puts opt.help; exit 1}
  opt.on('-d',        '--debug',    "enables debug mode") {$DEBUG = true}
  opt.on("-w",        '--warn',     "turns on warnings") {$-w = true}
end

