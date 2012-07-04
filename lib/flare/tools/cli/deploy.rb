# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

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
        desc "deploy for Debian-based system."
        usage "deploy [hostname:port:balance:partition] ..."
  
        def setup(opt)
          opt.on('--deploy-index',                        "deploy the index server") {@deploy_index = true}
          opt.on('--delete',                              "delete existing contents before deploying") {@delete = true}
          opt.on('--flarei=PATH',                       "a path for flarei executable") {|v| @flarei = v}
          opt.on('--flared=PATH',                       "a path for flared executable") {|v| @flared = v}
          opt.separator('flarei/flared options:')
          opt.on('--back-log=BACKLOG',                  "back log parameter for listen()"    ) {|v| @iconf["back-log"] = v}
          opt.on('--thread-pool-size=SIZE',             "thread pool size"                   ) {|v| @iconf["thread_pool_size"] = @dconf["thread_pool_size"] = v}
          opt.on('--daemonize=BOOL',                    "daemonize"                          ) {|v| @iconf["daemonize"] = @dconf["daemonize"] = v}
          opt.on('--data-dir=PATH',                     "data directory"                     ) {|v| @iconf["data-dir"] = @dconf["data-dir"] = v}
          opt.on('--log-facility=NAME',                 "log facility"                       ) {|v| @iconf["log-facility"] = @dconf["log-facility"] = v}
          opt.on('--max-connection=SIZE',               "max connection"                     ) {|v| @iconf["max-connection"] = @dconf["max-connection"] = v}
          opt.on('--net-read-timeout=MILLISECOND',      "read timeout for server connections") {|v| @iconf["net-read-timeout"] = @dconf["net-read-timeout"] = v}
          opt.on('--stack-size=KB',                     "stack size"                         ) {|v| @iconf["stack-size"] = @dconf["stack-size"] = v}
          opt.separator('flarei options:')
          opt.on('--monitor-threshold=COUNT',           "monitor threshold"                  ) {|v| @iconf["monitor-threshold"] = v}
          opt.on('--monitor-interval=SECOND',           "monitor interval"                   ) {|v| @iconf["monitor-interval"] = v}
          opt.on('--monitor-read-timeout=MILLISECOND',  "monitor read timeout in millisecond") {|v| @iconf["monitor-read-timeout"] = v}
          opt.on('--partition-type=NAME',               "partition type(modular)"            ) {|v| @iconf["partition-type"] = v}
          opt.on('--key-hash-algorithm=NAME'            "hash algorithm for key distribution") {|v| @iconf["key-hash-algorithm"] = v}
          opt.separator('flared options:')
          opt.on('--proxy-concurrency=SIZE',            "proxy concurrency"                  ) {|v| @dconf["proxy-concurrency"] = v}
          opt.on('--mutex-slot=SIZE',                   "mutex slot size"                    ) {|v| @dconf["mutex-slot"]= v}
          opt.on('--reconstruction-interval=MICROSEC',  "reconstruction interval"            ) {|v| @dconf["reconstruction-interval"] = v}
          opt.on('--reconstruction-bwlimit=BYTES',      "reconstruction bandwitdh limit"     ) {|v| @dconf["reconstruction-bwlimit"] = v}
          opt.on('--storage-ap=SIZE',                   "alignment power"                    ) {|v| @dconf["storage-ap"] = v}
          opt.on('--storage-bucket-size=SIZE',          "storage bucket size"                ) {|v| @dconf["storage-bucket-size"] = v}
          opt.on('--storage-cache-size=SIZE',           "storage cache size"                 ) {|v| @dconf["storage-cache-size"] = v}
          opt.on('--storage-compress=NAME',             "storage compress type(deflate|bz2|tcbs)") {|v| @dconf["storage-compress"] = v}
          opt.on('--storage-large',                       "strage large"                       ) {@dconf["storage-large"] = true}
          opt.on('--storage-type=NAME',                 "storage type"                       ) {|v| @dconf["storage-type"] = v}
          opt.on('--proxy-prior-netmask=SIZE',          "proxy priority mask (ex. 24 for 255.255.255.0)") {|v| @dconf["proxy-prior-netmask"] = v}
          opt.on('--max-total-thread-queue=SIZE',       "max total thread queue"             ) {|v| @dconf["max-total-thread-queue"] = v}
          opt.on('--index-servers=NAME',                "index servers"                      ) {|v| @dconf["index-servers"] = v}
          opt.on('--noreply-window-limit=SIZE',         "noreply window limit (experimental)") {|v| @dconf["noreply-window-limit"] = v}
          opt.on('--mysql-replication',                   "MySQL replication (experimental)"   ) {@dconf["mysql-replication"] = true}
          opt.on('--mysql-replication-port=PORT',       "MySQL replication port (experimental)") {|v| @dconf["mysql-replication-port"] = v}
          opt.on('--mysql-replication-id=ID',           "MySQL replication ID (experimental)") {|v| @dconf["mysql-replication-id"] = v}
          opt.on('--mysql-replication-db=NAME',         "MySQL replication DB (experimental)") {|v| @dconf["mysql-replication-db"] = v}
          opt.on('--mysql-replication-table=NAME',      "MySQL replication table (experimental)") {|v| @dconf["mysql-replication-table"] = v}
          opt.on('--proxy-cache-size=SIZE',             "proxy cache entry size (experimental)") {|v| @dconf["proxy-cache-size"] = v}
          opt.on('--proxy-cache-expire=SECOND',         "cache life-time in second (experimental)") {|v| @dconf["proxy-cache-expire"] = v}

        end

        def initialize
          @deploy_index = false
          @delete = false
          @flarei = "/usr/local/bin/flarei"
          @flared = "/usr/local/bin/flared"
          @iconf = {}
          @dconf = {}
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

            delete_all(basedir) if @delete && FileTest.exist?(basedir)
            if FileTest.exist?(basedir)
              warn "directory already exists: #{basedir}"
            else
              Dir.mkdir(basedir)
            end

            conf = Flare::Util::FlareiConf.new({
                                                 'server-name' => hostname,
                                                 'server-port' => port,
                                                 'data-dir' => datadir,
                                               }.merge(@iconf))
            open(basedir+"/flarei.conf", "w") {|f| f.puts conf}
            Dir.mkdir(datadir) unless FileTest.exist?(datadir)
            output_scripts(basedir, datadir, "flarei", @flarei)
          end

          args.each do |host|
            hostname, port, balance, partition = host.split(':', 4)
            hostname_port = "#{hostname}:#{port}"
            basedir = Dir.pwd+"/"+hostname_port
            datadir = basedir+"/data"

            info "generateing ... #{hostname_port}"
            delete_all(basedir) if @delete && FileTest.exist?(basedir)
            if FileTest.exist?(basedir)
              warn "directory already exists: #{basedir}"
            else
              Dir.mkdir(basedir)
            end

            if @dconf.has_key?("index-servers")
              @dconf['index-server-name'] = nil
              @dconf['index-server-port'] = nil
            end

            conf = Flare::Util::FlaredConf.new({
                                                 'index-server-name' => config[:index_server_hostname],
                                                 'index-server-port' => config[:index_server_port],
                                                 'server-name' => hostname,
                                                 'server-port' => port,
                                                 'data-dir' => datadir,
                                               }.merge(@dconf))
            open(basedir+"/flared.conf", "w") {|f| f.puts conf}
            Dir.mkdir(datadir) unless FileTest.exist?(datadir)
            output_scripts(basedir, datadir, "flared", @flared)
          end

          return 0
        end
        
      end
    end
  end
end
