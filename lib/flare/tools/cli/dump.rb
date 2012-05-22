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

begin
  require 'tokyocabinet'
rescue LoadError => e
end

module Flare
  module Tools
    module Cli
      
      class Dump < SubCommand

        class Dumper
          attr_reader :name
          def write data, key, flag, len, version, expire
            raise "internal error"
          end
          def close
            raise "internal error"
          end
        end

        class DefaultDumper < Dumper
          def self.myname
            "default"
          end
          def initialize filepath_or_writable
            @output = if filepath_or_writable.kind_of?(String)
                        open(filepath_or_writable, 'w') 
                      else
                        filepath_or_writable
                      end
          end
          def write data, key, flag, len, version, expire
            @output.puts "#{key} #{flag} #{len} #{version} #{expire} '#{data}'"
          end
          def close
            @output.close unless @output == STDOUT || @output == STDERR
          end
        end

        class CsvDumper < Dumper
          def self.myname
            "csv"
          end
          def initialize filepath_or_writable
            @output = if filepath_or_writable.kind_of?(String)
                        open(filepath_or_writable, 'w')
                      else
                        filepath_or_writable
                      end
            @output.puts "# key, flag, len, version, expire, data"
            @writer = CSV::Writer.generate(@output, ',')
          end
          def write data, key, flag, len, version, expire
            @writer << [key, flag, len, version, expire, data]
          end
          def close
            @output.close unless @output == STDOUT || @output == STDERR
          end
        end

        class TchDumper < Dumper
          def self.myname
            "tch"
          end
          def initialize filepath
            raise "output file not specified." if filepath.nil?
            raise "#{filepath} isn't a path." unless filepath.kind_of?(String)
            @hdb = TokyoCabinet::HDB.new
            @hdb.open(filepath, TokyoCabinet::HDB::OCREAT|TokyoCabinet::HDB::OWRITER)
          end
          def write data, key, flag, size, version, expire
            # uint32_t flag -> L    // uint32_t
            # time_t   expire -> Q  // unsigned long
            # uint64_t size -> Q    // uint64_t
            # uint64_t version -> Q // uint64_t
            # uint32_t option -> L  // uint32_t
            value = [flag, expire, size, version].pack("LQQQ")+data
            @hdb.put(key, value)
          end
          def close
            @hdb.close
          end
        end

        Iterators = [DefaultDumper, CsvDumper]
        Iterators << TchDumper if defined? TokyoCabinet
        Formats = Iterators.map {|n| n.myname}
        SizeOfByte = 8

        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :dump
        desc   "dump data from nodes. (experimental)"
        usage  "dump [hostname:port] ..."
        
        def setup(opt)
          opt.on('-o', '--output=[FILE]',            "output to file") {|v| @output = v}
          opt.on('-f', '--format=[FORMAT]',          "specify output format [#{Formats.join(',')}]") {|v| @format = v}
          opt.on(      '--bwlimit=[BANDWIDTH]',      "specify bandwidth limit (bps)") {|v|
            @bwlimit = Flare::Util::Bwlimit.bps(v)
          }
          opt.on('--all',                            "dump from all master nodes") {|v| @all = true}
          opt.on('--raw',                            "raw dump mode (for debugging)") {|v| @raw = true}
        end

        def initialize
          super
          @output = nil
          @format = nil
          @bwlimit = 0
          @all = false
          @raw = false
          @partition_size = 1
        end

        def execute(config, *args)
          STDERR.puts "please install tokyocabinet via gem command." unless defined? TokyoCabinet

          cluster = nil
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
          end
          return S_NG if cluster.nil?

          partition_size = cluster.partition_size

          if @all
            if args.size > 0
              STDERR.puts "don't specify any nodes with --all option."
              return S_NG
            else
              args = cluster.master_nodekeys
            end
          else
            if args.size == 0
              STDERR.puts "please specify --all option to get complete dump."
              return S_NG
            end
          end

          unless Formats.include?(@format)
            STDERR.puts "unknown format: #{@format}"
            return S_NG
          end

          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size == 2
              x << cluster.partition_of_nodename("#{x[0]}:#{x[1]}")
            elsif x.size == 4
              if x[3] =~ /^\d+$/
                STDERR.puts "invalid partition number '#{x.join(':')}'."
                x[3] = x[3].to_i
              else
                STDERR.puts "invalid partition number '#{x.join(':')}'."
                return S_NG
              end
            else
              STDERR.puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end
          
          dumper = case @format
                   when CsvDumper.myname
                     CsvDumper.new(@output || STDOUT)
                   when TchDumper.myname
                     TchDumper.new @output
                   else
                     DefaultDumper.new(@output || STDOUT)
                   end

          hosts.each do |hostname,port,partition|
            Flare::Tools::Node.open(hostname, port.to_i, config[:timeout], 0, @bwlimit) do |n|
              interval = 0
              part, partsize = if @raw
                                 [0, 1]
                               else
                                 [partition, partition_size]
                               end
              bwlimit = @bwlimit/1024/SizeOfByte
              count = 0
              STDERR.print "dumping from #{hostname}:#{port}::#{part} of #{partsize} partitions ... "
              n.dump(interval, part, partsize, bwlimit) do |data, key, flag, len, version, expire|
                dumper.write data, key, flag, len, version, expire
                count += 1
                false
              end
              STDERR.puts "#{count}"
            end
          end

          dumper.close
          
          S_OK
        end # execute()

      end
    end
  end
end

