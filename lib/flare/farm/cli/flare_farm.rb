# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'optparse'
require 'flare/util/logging'
require 'flare/util/constant'
require 'flare/farm/cli'

require 'flare/util/command_line'

include Flare::Util::Logging
include Flare::Util::Constant

module Cli
  include Flare::Farm::Cli
end

index_server_hostname = DefaultIndexServerName
index_server_port = DefaultIndexServerPort
timeout = DefaultTimeout
dry_run = false
scname = ''
subc = nil

scname = ARGV[0].to_sym if ARGV.size > 0
scclasses = [Cli::Init, Cli::Create]
unsupported = []
scclasses.concat unsupported

subcommands = Hash[*scclasses.map {|x| [x.to_sym, x]}.flatten]

setup do |opt|
  opt.banner = "Usage: flare-farm [subcommand] [options] [arguments]"
  
  if subcommands.include?(scname)
    subc = subcommands[scname].new 
    opt.separator("#{scname} subcommand:")
    subc.setup(opt)
  else
    error "unknown subcommand '#{scname}'" unless scname == ''
    opt.separator("subcommands:")
    puts opt.help
    subcommands.each do |k,v|
      next if unsupported.include?(v)
      o = OptionParser.new
      o.banner = "[#{k.to_s}] "+v.desc
      o.separator("  Usage: flare-farm "+v.usage)
      v.new.setup(o)
      puts o.help
    end
    exit 1
  end
end

execute do |args|
  command = args.shift
  subc.execute({ :command => command },
               *args) if subc
end

