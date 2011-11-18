# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

# 
module Flare
  module Util

    # == Description
    # Logger is a custom logging class.
    class Logger
      Info = :info
      Warn = :warn
      Trace = :trace
      Error = :error
      Debug = :debug

      def initialize(output = nil)
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
