# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'optparse'
require 'flare/util/logging'
require 'flare/util/constant'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/tools/cli/cli_util'

require 'flare/util/command_line'

Version = Flare::Tools::VERSION
include Flare::Util::Logging
include Flare::Util::Constant
include Flare::Tools::Cli::CliUtil
Cli = Flare::Tools::Cli

index_server_hostname = nil
index_server_port = nil
timeout = DefaultTimeout
dry_run = false
cluster = nil
scname = ''
subc = nil

scclasses = [Cli::List, Cli::Balance, Cli::Down, Cli::Slave, Cli::Reconstruct, Cli::Master, Cli::Threads, Cli::Ping, Cli::Remove, Cli::Index, Cli::Activate, Cli::Dump, Cli::Dumpkey, Cli::Verify, Cli::Stats, Cli::Restore]
unsupported = [Cli::Deploy]
scclasses.concat unsupported

subcommands = Hash[*scclasses.map {|x| [x.to_sym, x]}.flatten]

setup do |opt|
  opt.banner = "#{Flare::Tools::TITLE}\nUsage: flare-admin [subcommand] [options] [arguments]"
  opt.on("-n",  '--dry-run',                  "dry run")                                                  {dry_run = true}
  opt.on("-i",  '--index-server=[HOSTNAME]',  "index server hostname(default:#{DefaultIndexServerName})") {|v| index_server_hostname = v}
  opt.on("-p",  '--index-server-port=[PORT]', "index server port(default:#{DefaultIndexServerPort})")     {|v| index_server_port = v.to_i}
  opt.on(       '--log-file=[LOGFILE]',       "output log to LOGFILE")                                    {|v| Flare::Util::Logging.set_logger(v)}
  opt.on(       '--cluster=[NAME]',           "specify a cluster name")                                   {|v| cluster = v}
  
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
  command = args.shift
  ihostname, iport = get_index_server_from_nodekeys(args) ||
    get_index_server_name_and_port(index_server_hostname, index_server_port)
  ihostname, iport = get_index_server_from_cluster(cluster) unless cluster.nil?
  subc.execute({ :command => command,
                 :index_server_hostname => ihostname,
                 :index_server_port => iport,
                 :dry_run => dry_run,
                 :timeout => timeout },
               *args) if subc
end

exit status
