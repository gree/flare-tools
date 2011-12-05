# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'resolv'
require 'flare/tools/stats.rb'
require 'flare/tools/cli/part'
require 'flare/util/command_line.rb'
require 'flare/util/conversion.rb'

include Flare::Util::Logging
include Flare::Util::Constant

index_server_hostname = DefaultIndexServerName
index_server_port = DefaultIndexServerPort
timeout = DefaultTimeout
dry_run = false

if ENV.has_key? "FLARE_INDEX_SERVER"
  h, p = ENV["FLARE_INDEX_SERVER"].split(':')
  index_server_hostname = h unless h.nil?
  index_server_port = p unless p.nil?
end

subc = Flare::Tools::Cli::Part.new

setup do |opt|
  opt.banner = "Usage: flare-stats [options]"
  opt.on("-n",  '--dry-run',                  "dry run") {dry_run = true}
  opt.on('-i',  '--index-server=[HOSTNAME]',  "index server hostname(default:#{index_server_hostname})") {|v| index_server_hostname = v}
  opt.on('-p',  '--index-server-port=[PORT]', "index server port(default:#{index_server_port})") {|v| index_server_port = v.to_i}
  opt.on(       '--log-file=[LOGFILE]',       "outputs log to LOGFILE") {|v| Flare::Util::Logging.set_logger(v)}

  subc.setup(opt)
end

execute do |args|
  subc.execute({ :command => 'stats',
                 :index_server_hostname => index_server_hostname,
                 :index_server_port => index_server_port,
                 :dry_run => dry_run,
                 :timeout => timeout },
               *args)
end
