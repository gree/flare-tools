# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'timeout'
require 'singleton'
require 'thread'

require 'flare/util/flarei_conf'
require 'flare/util/flared_conf'

# 
module Flare
  module Test
    class Daemon
      include Singleton
  
      Flarei = "/usr/local/bin/flarei"
      Flared = "/usr/local/bin/flared"
      
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
          rescue Errno::ESRCH
            STDERR.print "?"
          rescue TimeoutError => e
            Process.kill :KILL, pid
            Process.waitpid pid
            STDERR.print "*"
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

      def invoke_flarei(name, config, executable = Flarei)
        config = Flare::Util::FlareiConf.new(config)
        conf = "/tmp/flarei.#{name}.#{config.server_port}.conf"
        open(conf, "w") do |f|
          f.puts config.to_s
        end
        pid = fork
        if pid.nil?
          deleteall(config.data_dir)
          Dir.mkdir(config.data_dir)
          exec executable, "-f", conf
          exit 1
        else
          @flarei << pid
          @tempfiles << config.data_dir
          @tempfiles << conf
        end
        pid
      end

      def invoke_flared(name, config, executable = Flared)
        config = Flare::Util::FlaredConf.new(config)
        conf = "/tmp/flared.#{name}.#{config.server_port}.conf"
        open(conf, "w") do |f|
          f.puts config.to_s
        end
        pid = fork
        if pid.nil?
          deleteall(config.data_dir)
          Dir.mkdir(config.data_dir)
          exec executable, "-f", conf
          exit 1
        else
          @flared << pid
          @tempfiles << config.data_dir
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
