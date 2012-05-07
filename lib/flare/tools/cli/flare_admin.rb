# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'optparse'
require 'flare/util/logging'
require 'flare/util/constant'
require 'flare/tools'
require 'flare/tools/cli'

require 'flare/util/command_line'

Version = Flare::Tools::VERSION
include Flare::Util::Logging
include Flare::Util::Constant
Cli = Flare::Tools::Cli

index_server_hostname = nil
index_server_port = nil
timeout = DefaultTimeout
dry_run = false
scname = ''
subc = nil

scclasses = [Cli::List, Cli::Balance, Cli::Down, Cli::Slave, Cli::Reconstruct, Cli::Master, Cli::Threads, Cli::Ping, Cli::Remove, Cli::Index, Cli::Activate, Cli::Dump, Cli::Dumpkey, Cli::Verify, Cli::Stats, Cli::Restore]
unsupported = [Cli::Deploy]
scclasses.concat unsupported

subcommands = Hash[*scclasses.map {|x| [x.to_sym, x]}.flatten]

setup do |opt|
  opt.banner = "#{Flare::Tools::TITLE}\nUsage: flare-admin [subcommand] [options] [arguments]"
  opt.on("-n",  '--dry-run',                  "dry run")                                                 {dry_run = true}
  opt.on("-i",  '--index-server=[HOSTNAME]',  "index server hostname(default:#{index_server_hostname})") {|v| index_server_hostname = v}
  opt.on("-p",  '--index-server-port=[PORT]', "index server port(default:#{index_server_port})")         {|v| index_server_port = v.to_i}
  opt.on(       '--log-file=[LOGFILE]',       "outputs log to LOGFILE")                                  {|v| Flare::Util::Logging.set_logger(v)}
  
  preparsed = opt.order(ARGV)
  scname = preparsed.shift.to_sym if preparsed.size > 0
  
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

status = execute do |args|
  if ENV.has_key? "FLARE_INDEX_SERVER"
    env_ihostname, env_iport = ENV["FLARE_INDEX_SERVER"].split(':')
  end

  command = args.shift
  ihostname, iport = index_server_hostname.split(':') unless index_server_hostname.nil?
  ihostname = ihostname || env_ihostname || DefaultIndexServerName
  if iport && index_server_port
    raise "--index-server-port option isn't allowed."
  else
    iport = index_server_port || env_iport || DefaultIndexServerPort if iport.nil?
  end
  subc.execute({ :command => command,
                 :index_server_hostname => ihostname,
                 :index_server_port => iport,
                 :dry_run => dry_run,
                 :timeout => timeout },
               *args) if subc
end

exit status
