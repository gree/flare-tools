# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'resolv'
require 'flare/tools/stats.rb'
require 'flare/tools/cli/stats'
require 'flare/util/command_line.rb'
require 'flare/util/conversion.rb'

include Flare::Util::Logging
include Flare::Util::Constant
include Flare::Util::Conversion


index_server_hostname = '127.0.0.1'
index_server_port = 12120
dry_run = false
timeout = 10
numeric_hosts = false

subc = Flare::Tools::Cli::Stats.new

setup do |opt|
  opt.banner = "Usage: flare-stats [options]"
#  opt.on("-n",  '--dry-run',                  "dry run") {dry_run = true}
  opt.on('-i',  '--index-server=[HOSTNAME]',  "index server hostname(default:#{index_server_hostname})") {|v| index_server_hostname = v}
  opt.on('-p',  '--index-server-port=[PORT]', "index server port(default:#{index_server_port})") {|v| index_server_port = v.to_i}
  subc.setup(opt)
end

Signal.trap(:INT) do
  subc.interrupt
end

execute do |args|
  subc.execute({ :command => 'stats',
                 :index_server_hostname => index_server_hostname,
                 :index_server_port => index_server_port,
                 :dry_run => dry_run,
                 :timeout => timeout },
               *args)
end
