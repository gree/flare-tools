# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/util/logging'
require 'flare/util/interruption'
require 'flare/tools/cli/option'

module Flare
  module Tools
    module Cli
      class SubCommand
        include Flare::Tools::Cli::Option

        @@myname = {}
        @@desc = {}
        @@usage = {}

        S_OK = 0
        S_NG = 1

        def self.to_sym
          myname
        end

        def self.myname(myname = nil)
          if myname.nil? then @@myname[name] else @@myname[name] = myname end
        end

        def self.usage(usage = nil)
          if usage.nil?
            @@usage[name] = "" unless @@usage.has_key?(name)
            @@usage[name]
          else
            @@usage[name] = usage
          end
        end

        def self.desc(desc = nil)
          if desc.nil?
            @@desc[name] = "" unless @@desc.has_key?(name)
            @@desc[name]
          else
            @@desc[name] = desc
          end
        end

        def myname
          myname = @@myname[self.class.name]
          if myname.nil? then "" else myname end
        end

        def self.to_s
          self.to_sym.to_s
        end

        def initialize
          option_init
        end

        def setup
          set_option_global
        end

        def execute_subcommand(config, args)
          setup
          rest_args = parse_options(config, args)

          execute(config, rest_args)
        end

        def execute
          raise "execute"
        end

        include Flare::Util::Logging
        include Flare::Util::Interruption
      end
    end
  end
end


