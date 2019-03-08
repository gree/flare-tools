# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

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

      FlareiVersion = `#{Flarei} -v`.chomp.split(' ')[-1]
      FlaredVersion = `#{Flared} -v`.chomp.split(' ')[-1]

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
          kill_node_process(pid)
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

      def required_version? required_version
        version = FlareiVersion.split('.').map {|i| i.to_i}
        (0...required_version.size).each do |i|
          n = if i < version.size then version[i] else 0 end
          return true if n > required_version[i]
          return false if n < required_version[i]
        end
        true
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
        config["key-hash-algorithm"] = "crc32" if required_version? [1, 0, 15]
        config = Flare::Util::FlareiConf.new(config)
        conf = "/tmp/flarei.#{name}.#{config.server_port}.conf"
        open(conf, "w") do |f|
          f.puts config.to_s
        end
        pid = fork
        if pid.nil?
          deleteall(config.data_dir)
          Dir.mkdir(config.data_dir)
          begin
            exec executable, "-f", conf
          rescue
            exit 1
          end
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
          begin
            exec executable, "-f", conf
          rescue
            exit 1
          end
        else
          @flared << pid
          @tempfiles << config.data_dir
          @tempfiles << conf
        end
        pid
      end

      def shutdown_flared(target_pid)
        STDERR.print "killing node..."
        @flared.each_with_index do |pid, i|
          next unless pid == target_pid
          kill_node_process(pid)
        end
        STDERR.print "\n"
        @flared.delete(target_pid)
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

      private

      def kill_node_process(pid)
        STDERR.print " #{pid}"
        begin
          Timeout.timeout(10) do
            Process.kill :TERM, pid
            Process.waitpid pid
          end
        rescue Errno::ESRCH
          STDERR.print "?"
        rescue Timeout::Error => e
          Process.kill :KILL, pid
          Process.waitpid pid
          STDERR.print "*"
        end
      end

    end
  end
end
