# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/index_server'
require 'flare/util/conversion'
require 'flare/tools/cli/sub_command'

# 
module Flare
  module Tools
    module Cli

      # == Description
      # 
      class List < SubCommand
        include Flare::Util::Conversion

        myname :list
        desc   "show the list of nodes in a flare cluster."
        usage  "list"
  
        def setup(opt)
          opt.on('--numeric-hosts',            "shows numerical host addresses") {@numeric_hosts = true}
        end

        def initialize
          super
          @numeric_hosts = false
        end

        def execute(config, *args)
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'].to_i, val['role'], key]}
            nodes.each do |n|
              puts n
            end
          end
          return 0
        end
        
      end
    end
  end
end

