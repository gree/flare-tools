# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/index_server'
require 'flare/util/conversion'
require 'flare/tools/cli/sub_command'

module Flare
  module Tools
    module Cli
      class Threads < SubCommand
        include Flare::Util::Conversion

        myname :threads
        desc   "show the list of threads in a flare cluster."
        usage  "threads [hostname:port]"
  
        def setup(opt)
        end

        def initialize
        end

        def execute(config, *args)
          header = [
                    ['%5s', 'id'],
                    ['%-32s', 'peer'],
                    ['%-13s', 'operation'],
                    ['%4s', 'type'],
                    ['%8s', 'queue']
                   ]
          format = header.map {|x| x[0]}.join(' ')

          if args.size > 1
            error "invalid arguments: "+args.join(' ')
            return S_NG
          end

          hostname = config[:index_server_hostname]
          port = config[:index_server_port]
          
          if args.size == 1
            hostname, port = args[0].split(':')
          end
          
          threads = []
          
          Flare::Tools::Stats.open(hostname, port, config[:timeout]) do |s|
            threads = s.stats_threads
            threads = threads.sort_by{|key,val| [val['peer'], key]}
          end
          
          puts format % header.map{|x| x[1]}.flatten

          threads.each do |thread_id, data|
            puts format % [
                           thread_id,
                           data['peer'],
                           if data['op'].nil? then "-" else data['op'] end,
                           data['type'],
                           data['queue'],
                          ]
          end
          
          S_OK
        end
        
      end
    end
  end
end
