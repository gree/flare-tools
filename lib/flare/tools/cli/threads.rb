# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/index_server'
require 'flare/util/conversion'
require 'flare/tools/common'
require 'flare/tools/cli/sub_command'
require 'flare/tools/cli/index_server_config'

module Flare
  module Tools
    module Cli
      class Threads < SubCommand
        include Flare::Util::Conversion
        include Flare::Tools::Common
        include Flare::Tools::Cli::IndexServerConfig

        myname :threads
        desc   "show the list of threads in a flare cluster."
        usage  "threads [hostname:port]"

        def setup
          super
          set_option_index_server
        end

        def initialize
          super
        end

        def execute(config, args)
          parse_index_server(config, args)
          header = [
                    ['%5s', 'id'],
                    ['%-32s', 'peer'],
                    ['%-13s', 'operation'],
                    ['%4s', 'type'],
                    ['%8s', 'queue']
                   ]
          format = header.map {|x| x[0]}.join(' ')

          hostname = config[:index_server_hostname]
          port = config[:index_server_port]

          if args.size == 1
            nodekey = nodekey_of args[0]
            if nodekey.nil?
              error "invalid nodekey: "+args[0]
              return S_NG
            end
            hostname, port = nodekey.split(':')
          elsif args.size > 1
            error "invalid arguments: "+args.join(' ')
            return S_NG
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
