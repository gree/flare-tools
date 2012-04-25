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
      
      class Restore < SubCommand

        class RestoreIterator
          attr_reader :name
          def iterate &block
            raise "internal error"
          end
          def close
            raise "internal error"
          end
        end

        class TchIt < RestoreIterator
          # uint32_t flag -> L    // uint32_t
          # time_t   expire -> Q  // unsigned long
          # uint64_t size -> Q    // uint64_t
          # uint64_t version -> Q // uint64_t
          # uint32_t option -> L  // uint32_t
          def self.myname
            "tch"
          end
          def initialize filepath
            raise "output file not specified." if filepath.nil?
            raise "#{filepath} isn't a path." unless filepath.kind_of?(String)
            @hdb = TokyoCabinet::HDB.new
            @hdb.open(filepath, TokyoCabinet::HDB::OCREAT|TokyoCabinet::HDB::OREADER)
          end
          def iterate &block
            @hdb.iterinit
            while (key = @hdb.iternext)
              value = @hdb.get(key)
              a = value.unpack("LQQQC*")
              flag, expire, size, version = a.shift(4)
              data = a.pack("C*")
              block.call(key, data, flag, expire)
            end
          end
          def close
            @hdb.close
          end
        end

        Iterators = []
        Iterators << TchIt if USE_TOKYOCABINET
        Formats = Iterators.map {|n| n.myname}

        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :restore
        desc   "restore data to nodes."
        usage  "restore [hostname:port]"
        
        def setup(opt)
          opt.on('-i', '--input=[FILE]',             "input from file") {|v| @input = v}
          opt.on('-f', '--format=[FORMAT]',          "input format [#{Formats.join(',')}]") {|v|
            @format = v
          }
          opt.on('--bwlimit=[BANDWIDTH]',            "bandwidth limit (bps)") {|v| @bwlimit = v}
          opt.on('--include=[PATTERN]',              "include pattern") {|v|
            begin
              @include = Regexp.new(v)
            rescue RegexpError => e
              raise "#{v} isn't a valid regular expression."
            end
          }
          opt.on('--exclude=[PATTERN]',              "exclude pattern") {|v|
            begin
              @exclude = Regexp.new(v)
            rescue RegexpError => e
              raise "#{v} isn't a valid regular expression."
            end
          }
        end

        def initialize
          super
          @input = nil
          @format = nil
          @wait = 0
          @part = 0
          @partsize = 1
          @bwlimit = 0
          @include = nil
          @exclude = nil
        end

        def execute(config, *args)

          unless @format.nil? || Formats.include?(@format)
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
          
          restorer = case @format
                     when TchIt.myname
                       TchIt.new(@input)
                     else
                       raise "invalid format"
                     end

          nodes = hosts.map do |hostname,port|
            Flare::Tools::Node.open(hostname, port.to_i, config[:timeout], @bwlimit, @bwlimit)
          end

          count = 0
          restorer.iterate do |key,data,flag,expire|
            if @include.nil? || @include =~ key
              next if @exclude && @exclude =~ key
              nodes[0].set(key, data, flag, expire)
              count += 1
            end
          end
          STDERR.puts "#{count} entries have been restored."

          nodes.each do |n|
            n.close
          end

          restorer.close
          
          S_OK
        end # execute()

      end
    end
  end
end


