# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/index_server'
require 'flare/util/conversion'
require 'flare/util/logging'
require 'flare/tools/cli/sub_command'

# 
module Flare
  module Tools

    # == Description
    # 
    module Cli
      class Ping < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Logging
        
        myname :ping
        desc   "ping"
        usage  "ping [hostname:port] ..."
        
        def setup(opt)
          opt.on('--wait',            "waits for alive") {@wait = true}
        end
        
        def initialize
          @wait = false
        end
        
        def execute(config, *args)
          resp = nil
          args.each do |arg|
            hostname, port = arg.split(':', 2)
            until resp
              begin
                interruptible do
                  debug "trying..."
                  Flare::Tools::Stats.open(hostname, port, config[:timeout]) do |s|
                    resp = s.ping
                  end
                end
              rescue IOError
                return 1
              rescue
                unless @wait
                  puts "down"
                  return 1
                end
                sleep 1
              end
            end
          end
          
          puts "alive"
          return 0
        end
        
      end
    end
  end
end
