# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/stats'
require 'flare/tools/node'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'

require 'csv'

module Flare
  module Tools
    module Cli
      
      class Dump < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        
        myname :dump
        desc   "dump data from nodes."
        usage  "dump [hostname:port] ..."
        
        def setup(opt)
          opt.on('-o', '--output=[FILE]',            "outputs to file") {|v| @output = v}
          opt.on('-f', '--format=[FORMAT]',          "output format (csv,tsv)") {|v| @format = v}
        end

        def initialize
          super
          @output = nil
          @format = nil
        end

        def execute(config, *args)
          return S_NG if args.size < 1

          hosts = args.map {|x| x.split(':')}
          hosts.each do |x|
            if x.size != 2
              puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end
          
          hosts.each do |hostname,port|
            Flare::Tools::Node.open(hostname, port.to_i, config[:timeout]) do |n|
              output = STDOUT
              unless @output.nil?
                output = File.open(@output, "w")
              end
              writer = CSV::Writer.generate(output)
              n.dump do |data, key, flag, len, cas|
                if @format == "csv"
                  writer << [key, data]
                else
                  output.puts "#{key} '#{data}'"
                end
              end
              output.close if output != STDOUT
            end
          end
          
          S_OK
        end # execute()
        
        def stat_one_node(s)
          
        end

      end
    end
  end
end

