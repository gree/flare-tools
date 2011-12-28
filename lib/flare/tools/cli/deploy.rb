# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/util'
require 'flare/tools/index_server'
require 'flare/tools/cli/sub_command'

# 
module Flare
  module Tools
    module Cli

      # == Description
      # 
      class Deploy < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::FileSystem

        myname :deploy
        desc "deploy."
        usage "deploy [hostname:port:balance:partition] ..."
  
        def setup(opt)
          opt.on('--proxy-concurrency=[CONC]',            "proxy concurrency") {|v| @proxy_concurrency = v.to_i}
          opt.on('--noreply-window-limit=[WINLIMIT]',     "noreply window limit") {|v| @noreply_window_limit = v.to_i}
          opt.on('--thread-pool-size=[SIZE]',             "thread pool size") {|v| @thread_pool_size = v.to_i}
          opt.on('--monitor-threshold=[COUNT]',           "monitor threshold") {|v| @monitor_threshold = v.to_i}
          opt.on('--monitor-interval=[SECOND]',           "monitor interval") {|v| @monitor_interval = v.to_i}
          opt.on('--monitor-read-timeout=[MILLISECOND]',  "monitor read timeout in millisecond") {|v| @monitor_read_timeout = v.to_i}
          opt.on('--deploy-index',                        "deploys index") {@deploy_index = true}
          opt.on('--delete',                              "deletes existing contents before deploying") {@delete = true}
        end

        def initialize
          @proxy_concurrency = 2
          @noreply_window_limit = nil
          @thread_pool_size = 16
          @deploy_index = false
          @monitor_threshold = 3
          @monitor_interval = 5
          @monitor_read_timeout = 1000
          @delete = false
          @flarei = "/usr/local/bin/flarei"
          @flared = "/usr/local/bin/flared"
        end

        def output_scripts(basedir, datadir, name, exec)
          starting = "/sbin/start-stop-daemon --start --quiet --pidfile #{datadir}/#{name}.pid --exec #{exec}"
          starting += " -- -f #{basedir}/#{name}.conf --daemonize"
          stopping = "/sbin/start-stop-daemon --stop --retry=TERM/30/KILL/5 --quiet --pidfile #{datadir}/#{name}.pid --exec #{exec}"

          start = basedir+"/start.sh"
          open(start, "w") do |f|
            f.puts "#!/bin/sh"
            f.puts starting
          end
          File.chmod(0744, start)
          
          stop = basedir+"/stop.sh"
          open(stop, "w") do |f|
            f.puts "#!/bin/sh"
            f.puts stopping
          end
          File.chmod(0744, stop)
          
          restart = basedir+"/restart.sh"
          open(restart, "w") do |f|
            f.puts "#!/bin/sh"
            f.puts stopping
            f.puts "sleep 5"
            f.puts starting
          end
          File.chmod(0744, restart)
        end

        def execute(config, *args)

          if @deploy_index
            hostname = config[:index_server_hostname]
            port = config[:index_server_port]
            hostname_port = "#{hostname}:#{port}"
            basedir = Dir.pwd+"/"+hostname_port
            datadir = basedir+"/data"

            if @delete
              delete_all(basedir) if FileTest.exist?(basedir)
            end

            if FileTest.exist?(basedir)
              warn "directory already exists: #{basedir}"
            else
              Dir.mkdir(basedir)
            end

            conf = Flare::Util::FlareiConf.new({
                                                 'server-name' => hostname,
                                                 'server-port' => port,
                                                 'data-dir' => datadir,
                                               })
            open(basedir+"/flarei.conf", "w") do |f|
              f.puts conf
            end
            unless FileTest.exist?(datadir)
              Dir.mkdir(datadir)
            end
            output_scripts(basedir, datadir, "flarei", @flarei)
          end

          args.each do |host|
            hostname, port, balance, partition = host.split(':', 4)
            hostname_port = "#{hostname}:#{port}"
            basedir = Dir.pwd+"/"+hostname_port
            datadir = basedir+"/data"

            info "generateing ... #{hostname_port}"

            if @delete
              delete_all(basedir) if FileTest.exist?(basedir)
            end


            if FileTest.exist?(basedir)
              warn "directory already exists: #{basedir}"
            else
              Dir.mkdir(basedir)
            end

            modifier = {
              'index-server-name' => config[:index_server_hostname],
              'index-server-port' => config[:index_server_port],
              'server-name' => hostname,
              'server-port' => port,
              'data-dir' => datadir,
              'proxy-concurrency' => @proxy_concurrency,
              'thread-pool-size' => @thread_pool_size,
              'monitor-interval' => @monitor_interval,
              'monitor-threshold' => @monitor_threshold,
              'monitor-read-timeout' => @monitor_read_timeout,
            }

            unless @noreply_window_limit.nil?
              modifier['noreply-window-limit'] = @noreply_window_limit
            end

            conf = Flare::Util::FlaredConf.new(modifier)
            open(basedir+"/flared.conf", "w") do |f|
              f.puts conf
            end
            unless FileTest.exist?(datadir)
              Dir.mkdir(datadir)
            end
            output_scripts(basedir, datadir, "flared", @flared)
          end

          return 0
        end
        
      end
    end
  end
end
