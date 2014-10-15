# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/util'
require 'flare/tools/index_server'
require 'flare/tools/cli/sub_command'
require 'flare/tools/cli/index_server_config'

module Flare
  module Tools
    module Cli

      class Deploy < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::FileSystem
        include Flare::Tools::Cli::IndexServerConfig

        myname :deploy
        desc "deploy for Debian-based system."
        usage "deploy [hostname:port:balance:partition] ..."

        def setup
          super
          set_option_index_server
          @optp.on('--deploy-index',                        "deploy the index server") {@deploy_index = true}
          @optp.on('--delete',                              "delete existing contents before deploying") {@delete = true}
          @optp.on('--flarei=PATH',                       "a path for flarei executable") {|v| @flarei = v}
          @optp.on('--flared=PATH',                       "a path for flared executable") {|v| @flared = v}
          @optp.separator('flarei/flared options:')
          @optp.on('--back-log=BACKLOG',                  "back log parameter for listen()"    ) {|v| @iconf["back-log"] = v}
          @optp.on('--thread-pool-size=SIZE',             "thread pool size"                   ) {|v| @iconf["thread_pool_size"] = @dconf["thread_pool_size"] = v}
          @optp.on('--daemonize=BOOL',                    "daemonize"                          ) {|v| @iconf["daemonize"] = @dconf["daemonize"] = v}
          @optp.on('--data-dir=PATH',                     "data directory"                     ) {|v| @iconf["data-dir"] = @dconf["data-dir"] = v}
          @optp.on('--log-facility=NAME',                 "log facility"                       ) {|v| @iconf["log-facility"] = @dconf["log-facility"] = v}
          @optp.on('--max-connection=SIZE',               "max connection"                     ) {|v| @iconf["max-connection"] = @dconf["max-connection"] = v}
          @optp.on('--net-read-timeout=MILLISECOND',      "read timeout for server connections") {|v| @iconf["net-read-timeout"] = @dconf["net-read-timeout"] = v}
          @optp.on('--stack-size=KB',                     "stack size"                         ) {|v| @iconf["stack-size"] = @dconf["stack-size"] = v}
          @optp.separator('flarei options:')
          @optp.on('--monitor-threshold=COUNT',           "monitor threshold"                  ) {|v| @iconf["monitor-threshold"] = v}
          @optp.on('--monitor-interval=SECOND',           "monitor interval"                   ) {|v| @iconf["monitor-interval"] = v}
          @optp.on('--monitor-read-timeout=MILLISECOND',  "monitor read timeout in millisecond") {|v| @iconf["monitor-read-timeout"] = v}
          @optp.on('--partition-type=NAME',               "partition type(modular)"            ) {|v| @iconf["partition-type"] = v}
          @optp.on('--key-hash-algorithm=NAME'            "hash algorithm for key distribution") {|v| @iconf["key-hash-algorithm"] = v}
          @optp.separator('flared options:')
          @optp.on('--proxy-concurrency=SIZE',            "proxy concurrency"                  ) {|v| @dconf["proxy-concurrency"] = v}
          @optp.on('--mutex-slot=SIZE',                   "mutex slot size"                    ) {|v| @dconf["mutex-slot"]= v}
          @optp.on('--reconstruction-interval=MICROSEC',  "reconstruction interval"            ) {|v| @dconf["reconstruction-interval"] = v}
          @optp.on('--reconstruction-bwlimit=BYTES',      "reconstruction bandwitdh limit"     ) {|v| @dconf["reconstruction-bwlimit"] = v}
          @optp.on('--storage-ap=SIZE',                   "alignment power"                    ) {|v| @dconf["storage-ap"] = v}
          @optp.on('--storage-bucket-size=SIZE',          "storage bucket size"                ) {|v| @dconf["storage-bucket-size"] = v}
          @optp.on('--storage-cache-size=SIZE',           "storage cache size"                 ) {|v| @dconf["storage-cache-size"] = v}
          @optp.on('--storage-compress=NAME',             "storage compress type(deflate|bz2|tcbs)") {|v| @dconf["storage-compress"] = v}
          @optp.on('--storage-large',                       "strage large"                       ) {@dconf["storage-large"] = true}
          @optp.on('--storage-type=NAME',                 "storage type"                       ) {|v| @dconf["storage-type"] = v}
          @optp.on('--proxy-prior-netmask=SIZE',          "proxy priority mask (ex. 24 for 255.255.255.0)") {|v| @dconf["proxy-prior-netmask"] = v}
          @optp.on('--max-total-thread-queue=SIZE',       "max total thread queue"             ) {|v| @dconf["max-total-thread-queue"] = v}
          @optp.on('--index-servers=NAME',                "index servers"                      ) {|v| @dconf["index-servers"] = v}
          @optp.on('--noreply-window-limit=SIZE',         "noreply window limit (experimental)") {|v| @dconf["noreply-window-limit"] = v}
          @optp.on('--mysql-replication',                   "MySQL replication (experimental)"   ) {@dconf["mysql-replication"] = true}
          @optp.on('--mysql-replication-port=PORT',       "MySQL replication port (experimental)") {|v| @dconf["mysql-replication-port"] = v}
          @optp.on('--mysql-replication-id=ID',           "MySQL replication ID (experimental)") {|v| @dconf["mysql-replication-id"] = v}
          @optp.on('--mysql-replication-db=NAME',         "MySQL replication DB (experimental)") {|v| @dconf["mysql-replication-db"] = v}
          @optp.on('--mysql-replication-table=NAME',      "MySQL replication table (experimental)") {|v| @dconf["mysql-replication-table"] = v}
          @optp.on('--proxy-cache-size=SIZE',             "proxy cache entry size (experimental)") {|v| @dconf["proxy-cache-size"] = v}
          @optp.on('--proxy-cache-expire=SECOND',         "cache life-time in second (experimental)") {|v| @dconf["proxy-cache-expire"] = v}

        end

        def initialize
          super
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

        def execute(config, args)
          parse_index_server(config, args)

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
