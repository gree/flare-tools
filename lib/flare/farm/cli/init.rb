# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/util/conversion'
require 'flare/farm/cli/sub_command'

# 
module Flare
  module Farm
    module Cli

      # == Description
      # 
      class Init < SubCommand
        include Flare::Util::Conversion

        myname :init
        desc   "init a farm"
        usage  "init"
  
        def setup(opt)
          
        end

        def initialize
          super
        end

        def execute(config, *args)
          farmdir = "#{Farm::VarDir}/flarefarm"
          begin
            if File.exist?(farmdir)
              Dir.rmdir(farmdir)
            end
            Dir.mkdir(farmdir)
            File.chown(ENV['SUDO_UID'].to_i, ENV['SUDO_GID'].to_i, farmdir)
          rescue Errno::EACCES => e
            puts "Permission denied."
            puts " $sudo flare-farm init"
          rescue Errno::ENOENT => e
            puts e
          rescue => e
            p e
          end
        end        
      end
    end
  end
end

