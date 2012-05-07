# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/node'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/util/bwlimit'
require 'flare/tools/cli/sub_command'

require 'csv'

module Flare
  module Tools
    module Cli
      
      class Dumpkey < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :dumpkey
        desc   "dump key from nodes."
        usage  "dumpkey [hostname:port] ..."
        
        def setup(opt)
          opt.on('-o', '--output=[FILE]',            "outputs to file") {|v| @output = v}
          opt.on('-f', '--format=[FORMAT]',          "output format [csv]") {|v| @format = v}
          opt.on('-p', '--partition=[NUMBER]',       "partition number") {|v| @part = v.to_i if v.to_i >= 0}
          opt.on('-s', '--partition-size=[SIZE]',    "partition size") {|v| @partsize = v.to_i if v.to_i > 0}
          opt.on(      '--bwlimit=[BANDWIDTH]',      "bandwidth limit (bps)") {|v| @bwlimit = v if v.to_i > 0}
          opt.on(      '--all',                      "dump form all partitions") {@all = true}
        end

        def initialize
          super
          @output = nil
          @format = nil
          @part = nil
          @partsize = nil
          @bwlimit = nil
          @all = false
        end

        def execute(config, *args)
          cluster = nil
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
          end
          return S_NG if cluster.nil?

          if @all
            unless args.empty?
              STDERR.puts "don't specify any nodes with --all option."
              return S_NG
            else
              args = cluster.master_nodekeys
            end
          else
            if args.empty?
              STDERR.puts "please specify --all option to get complete dump."
              return S_NG
            end
          end

          unless @format.nil?
            unless ["csv"].include? @format
              puts "unknown format: #{@format}"
              return S_NG
            end
          end

          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size != 2
              puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end
          
          hosts.each do |hostname,port|
            Flare::Tools::Node.open(hostname, port.to_i, config[:timeout], @bwlimit, @bwlimit) do |n|
              output = STDOUT
              unless @output.nil?
                output = File.open(@output, "w")
              end
              case @format
              when "csv"
                writer = CSV::Writer.generate(output)
                output.puts "# key"
              end
              interruptible {
                n.dumpkey(@part, @partsize) do |key|
                  case @format
                  when "csv"
                    writer << [key]
                  else
                    output.puts "#{key}"
                  end
                  false
                end
              }
              output.close if output != STDOUT
            end
          end
          
          S_OK
        end # execute()
        
      end
    end
  end
end

