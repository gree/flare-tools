# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/util/conversion'
require 'flare/tools/cli/deploy'
require 'flare/farm/cli/sub_command'
require 'flare/farm/server'

# 
module Flare
  module Farm
    module Cli

      # == Description
      # 
      class Create < SubCommand
        include Flare::Util::Conversion

        myname :create
        desc   "create a cluster"
        usage  "create [clustername]"
  
        def setup(opt)
          
        end

        def initialize
          super
        end

        def execute(config, *args)
          clustername = args.shift
          hosts = args.map {|n| n.split(':')}

          hosts.each do |hostname, port|
            Flare::Farm::Server.new(hostname) do |s|
              basedir = "#{Farm::VarDir}/flarefarm/clusters"
              s.mkdir_p(basedir)
              clusterdir = "#{basedir}/#{clustername}"
              s.mkdir_p(clusterdir)
              s.deploy(clusterdir, "#{hostname}:#{port}")
            end
          end

          return S_OK
        rescue => e
          puts e
          raise e
        end        
      end
    end
  end
end

