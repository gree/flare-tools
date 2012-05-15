# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

cliname = File.basename($PROGRAM_NAME)
cliname[/flare-/] = ""

require 'resolv'
require 'flare/tools'
require 'flare/tools/cli/cli_util'
require 'flare/util/logging'
begin
  require "flare/tools/cli/#{cliname}"
rescue LoadError
  exit 1
end
require 'flare/util/command_line.rb'
require 'flare/util/conversion.rb'

include Flare::Util::Logging
include Flare::Util::Constant
include Flare::Tools::Cli::CliUtil

index_server_hostname = nil
index_server_port = nil
timeout = DefaultTimeout
dry_run = false
cluster = nil

if ENV.has_key? "FLARE_INDEX_SERVER"
  h, p = ENV["FLARE_INDEX_SERVER"].split(':')
  index_server_hostname = h unless h.nil?
  index_server_port = p unless p.nil?
end

subc = eval "Flare::Tools::Cli::#{cliname.capitalize}.new"

setup do |opt|
  opt.banner = "#{Flare::Tools::TITLE}\nUsage: flare-#{cliname} [options]"
  opt.on('-n',  '--dry-run',                  "dry run") {dry_run = true}
  opt.on('-i',  '--index-server=[HOSTNAME]',  "index server hostname(default:#{DefaultIndexServerName})") {|v| index_server_hostname = v}
  opt.on('-p',  '--index-server-port=[PORT]', "index server port(default:#{DefaultIndexServerPort})") {|v| index_server_port = v.to_i}
  opt.on(       '--log-file=[LOGFILE]',       "output log to LOGFILE") {|v| Flare::Util::Logging.set_logger(v)}
  opt.on(       '--cluster=[NAME]',           "specify a cluster name") {|v| cluster = v}

  subc.setup(opt)
end

execute do |args|
  ihostname, iport = get_index_server_from_cluster(cluster) ||
    get_index_server_from_nodekeys(args) ||
    get_index_server_name_and_port(index_server_hostname, index_server_port)
  subc.execute({ :command => File.basename($PROGRAM_NAME),
                 :index_server_hostname => ihostname,
                 :index_server_port => iport,
                 :dry_run => dry_run,
                 :timeout => timeout },
               *args)
end
