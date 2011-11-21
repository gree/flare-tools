# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'optparse'
require 'flare/util/logging'
require 'flare/util/constant'
require 'flare/tools/cli'

require 'flare/util/command_line'

include Flare::Util::Logging
include Flare::Util::Constant
Cli = Flare::Tools::Cli

index_server_hostname = DefaultIndexServerName
index_server_port = DefaultIndexServerPort
timeout = DefaultTimeout
dry_run = false
scname = ''
subc = nil

if ENV.has_key? "FLARE_INDEX_SERVER"
  h, p = ENV["FLARE_INDEX_SERVER"].split(':')
  index_server_hostname = h unless h.nil?
  index_server_port = p unless p.nil?
end

scname = ARGV[0].to_sym if ARGV.size > 0
scclasses = [Cli::List, Cli::Stats, Cli::Balance, Cli::Down, Cli::Slave, Cli::Reconstruct, Cli::Index, Cli::Master, Cli::Deploy, Cli::Threads, Cli::Ping]
unsupported = [] # [Cli::Master, Cli::Deploy]

subcommands = Hash[*scclasses.map {|x| [x.to_sym, x]}.flatten]

setup do |opt|
  opt.banner = "Usage: flare-admin [subcommand] [options] [arguments]"
  opt.on("-n",  '--dry-run',                  "dry run") {dry_run = true}
  opt.on("-i",  '--index-server=[HOSTNAME]',  "index server hostname(default:#{index_server_hostname})") {|v| index_server_hostname = v}
  opt.on("-p",  '--index-server-port=[PORT]', "index server port(default:#{index_server_port})") {|v| index_server_port = v.to_i}
  opt.on(       '--log-file=[LOGFILE]',       "outputs log to LOGFILE") {|v| Logging.set_logger(v)}
  
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
      o.separator("  Usage: flare-admin "+v.usage)
      v.new.setup(o)
      puts o.help
    end
    exit 1
  end
end

Signal.trap(:INT) do
  subc.interrupt
end

execute do |args|
  command = args.shift
  subc.execute({ :command => command,
                 :index_server_hostname => index_server_hostname,
                 :index_server_port => index_server_port,
                 :dry_run => dry_run,
                 :timeout => timeout },
               *args) if subc
end
