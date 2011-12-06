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
          super
          @wait = false
        end
        
        def execute(config, *args)

          hosts = args.map do |arg|
            hostname, port, rest = arg.split(':', 3)
            if !rest.nil? || hostname.nil? || hostname.empty? || port.nil? || port.empty?
              error "invalid argument '#{arg}'. it must be hostname:port."
              return S_NG
            end
            begin
              ipaddr = Resolv.getaddress(hostname)
            rescue Resolv::ResolvError
              error "unknown host '#{hostname}'"
              return S_NG
            end
            [hostname, port]
          end

          hosts.each do |hostname, port|
            resp = nil
            until resp
              begin
                debug "trying..."
                interruptible do
                  Flare::Tools::Stats.open(hostname, port, config[:timeout]) do |s|
                    resp = s.ping
                  end
                end
              rescue IOError
                return S_NG
              rescue
                unless @wait
                  puts "#{hostname}:#{port} is down"
                  return S_NG
                end
                interruptible {sleep 1}
              end
            end
          end
          
          puts "alive"
          S_OK
        end
        
      end
    end
  end
end
