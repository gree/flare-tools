# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'rubygems'
require 'openssl'
require 'net/ssh'
require 'flare/farm'

module Flare
  module Farm
    class Server

      def initialize(hostname, &block)
        @hostname = hostname
        @username = ENV['USER']
        @ssh = ::Net::SSH.start(@hostname, @username)
        unless block.nil?
          begin
            block.call(self)
          ensure
            @ssh.close
          end
        end
      end
      
      def cat(filepath)
        puts @ssh.exec! "cat #{filepath}"
      end

      def mkdir(filepath)
        puts "mkdir #{filepath}"
        puts @ssh.exec!("mkdir #{filepath}")
      end

      def mkdir_p(filepath)
        puts "mkdir -p #{filepath}"
        puts @ssh.exec!("mkdir -p #{filepath}")
      end

      def chdir(dirpath)
        puts "chdir #{dirpath}"
        puts @ssh.exec!("cd #{dirpath}")
      end

      def pwd()
        puts "pwd"
        puts @ssh.exec!("pwd")
      end

      def deploy(clusterdir, *args)
        puts "flare-deploy #{args.join(' ')}"
        puts @ssh.exec!("(cd #{clusterdir} && flare-deploy #{args.join(' ')})")
      end

    end
  end
end
