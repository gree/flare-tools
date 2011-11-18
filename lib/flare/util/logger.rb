# -*- coding: utf-8; -*-

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    #
    # == Description
    # Logger is a custom logging class.
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

  end
end
