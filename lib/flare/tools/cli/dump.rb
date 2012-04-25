# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/node'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'
require 'csv'

begin
  require 'tokyocabinet'
  USE_TOKYOCABINET = true unless defined? USE_TOKYOCABINET
rescue => e
  USE_TOKYOCABINET = false unless defined? USE_TOKYOCABINET
end

module Flare
  module Tools
    module Cli
      
      class Dump < SubCommand

        class DumpIterator
          attr_reader :name
          def write data, key, flag, len, version, expire
            raise "internal error"
          end
          def close
            raise "internal error"
          end
        end

        class DefaultIt < DumpIterator
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

        class CsvIt < DumpIterator
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

        class TchIt < DumpIterator
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

        Iterators = [DefaultIt, CsvIt]
        Iterators << TchIt if USE_TOKYOCABINET
        Formats = Iterators.map {|n| n.myname}
        SizeOfByte = 8

        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :dump
        desc   "dump data from nodes."
        usage  "dump [hostname:port] ..."
        
        def setup(opt)
          opt.on('-o', '--output=[FILE]',            "outputs to file") {|v| @output = v}
          opt.on('-f', '--format=[FORMAT]',          "output format [#{Formats.join(',')}]") {|v| @format = v}
          opt.on('--bwlimit=[BANDWIDTH]',            "bandwidth limit (bps)") {|v| @bwlimit = v.to_i}
          opt.on('--all',                            "dump from all nodes") {|v| @all = true}
        end

        def initialize
          super
          @output = nil
          @format = nil
          @wait = 0
          @part = 0
          @partsize = 1
          @bwlimit = 0
          @all = false
        end

        def execute(config, *args)
          if @all
            if args.size > 0
              puts "don't specify any nodes with --all option."
              return S_NG
            else
              Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
                cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
                args = cluster.master_node_list
              end
            end
          else
            return S_NG if args.size == 0
          end

          if !@format.nil? && !Formats.include?(@format)
            puts "unknown format: #{@format}"
            return S_NG
          end

          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size != 2
              puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end
          
          dumper = case @format
                   when CsvIt.myname
                     CsvIt.new(@output || STDOUT)
                   when TchIt.myname
                     TchIt.new @output
                   else
                     DefaultIt.new(@output || STDOUT)
                   end

          hosts.each do |hostname,port|
            Flare::Tools::Node.open(hostname, port.to_i, config[:timeout], @bwlimit, @bwlimit) do |n|
              n.dump(@wait, @part, @partsize, @bwlimit/SizeOfByte) do |data, key, flag, len, version, expire|
                dumper.write data, key, flag, len, version, expire
                false
              end
            end
          end

          dumper.close
          
          S_OK
        end # execute()

      end
    end
  end
end

