# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'timeout'
require 'singleton'
require 'thread'

module Flare
  module Test
    class Daemon
      include Singleton
  
      def initialize
        @flared = []
        @flarei = []
        @port = 20000+rand(10000)
        @port_mutex = Mutex.new
        @tempfiles = []
        Kernel.at_exit {
          Flare::Test::Daemon.instance.shutdown
        }
      end

      def shutdown
        STDERR.print "killing..."
        (@flared+@flarei).each do |pid|
          STDERR.print " #{pid}"
          begin
            timeout(10) do
              Process.kill :TERM, pid
              Process.waitpid pid
            end
          rescue TimeoutError => e
              Process.kill :KILL, pid
              Process.waitpid pid
          end
        end
        STDERR.print "\n"
        Process.waitall
        @flared.clear
        @flarei.clear
        @tempfiles.each do |datadir|
          deleteall(datadir)
        end
        @tempfiles.clear
      end

      def assign_port
        port = 0
        @port_mutex.synchronize do
          port = @port
          @port += 1
        end
        port
      end

      Flarei = "/usr/local/bin/flarei"
      FlareiConf = {
        'data-dir' => "/tmp",
        'log-facility' => "local0",
        'max-connection' => 256,
        'monitor-threshold' => 3,
        'monitor-interval' => 1,
        'server-name' => "localhost",
        'server-port' => 12120,
        'thread-pool-size' => 8,
      }
      
      def invoke_flarei(name, config)
        config = FlareiConf.merge(config)
        serverport = config['server-port']
        conf = "/tmp/flarei.#{name}.#{serverport}.conf"
        open(conf, "w") do |f|
          config.each do |k,v|
            f.puts("#{k} = #{v}")
          end
        end
        pid = fork
        if pid.nil?
          deleteall(config['data-dir'])
          Dir.mkdir(config['data-dir'])
          exec Flarei, "-f", conf
          exit 1
        else
          @flarei << pid
          @tempfiles << config['data-dir']
          @tempfiles << conf
        end
        pid
      end

      Flared = "/usr/local/bin/flared"
      FlaredConf = {
        'data-dir' => "/tmp",
        'index-server-name' => "localhost",
        'index-server-port' => "12120",
        'log-facility' => "local1",
        'max-connection' => "256",
        'mutex-slot' => "32",
        'proxy-concurrency' => "2",
        'server-name' => "localhost",
        'server-port' => "12121",
        'storage-type' => "tch",
        'thread-pool-size' => "16",
      }

      def invoke_flared(name, config)
        config = FlaredConf.merge(config)
        serverport = config['server-port']
        conf = "/tmp/flared.#{name}.#{serverport}.conf"
        open(conf, "w") do |f|
          config.each do |k,v|
            f.puts("#{k} = #{v}")
          end
        end
        pid = fork
        if pid.nil?
          deleteall(config['data-dir'])
          Dir.mkdir(config['data-dir'])
          exec Flared, "-f", conf
          exit 1
        else
          @flared << pid
          @tempfiles << config['data-dir']
          @tempfiles << conf
        end
        pid
      end

      def deleteall(delthem)
        return unless FileTest.exist?(delthem)
        if FileTest.directory?(delthem)
          Dir.foreach(delthem) do |file|
            next if /^\.+$/ =~ file
            deleteall(delthem.sub(/\/+$/,"") + "/" + file)
          end
          Dir.rmdir(delthem) rescue ""
        else
          File.delete(delthem)
        end
      end

    end
  end
end
