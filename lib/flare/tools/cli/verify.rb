# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/index_server'
require 'flare/tools/node'
require 'flare/util/conversion'
require 'flare/util/key_resolver'
require 'flare/util/hash_function'
require 'flare/tools/cli/sub_command'
require 'digest/md5'


# 
module Flare
  module Tools
    module Cli

      # == Description
      # 
      class Verify < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::HashFunction

        myname :verify
        desc   "verify the cluster."
        usage  "verify"
  
        def setup(opt)
          opt.on('--key-hash-algorithm=[TYPE]',            "key hash algorithm") do |v|
            case @key_hash_algorithm = v.to_sym
            when :simple, :crc32
            else
              puts "unknown type: #{v}"
              exit
            end
          end
          opt.on('--store-test-data',                      "store test data") {|v| @store_test_data = true}
          opt.on('--debug',                                "debug mode") {|v| @debug = true}
          opt.on('--32bit',                                "32bit mode") {|v| @word_size = 32}
        end

        def initialize
          super
          @machine_word_width
          @numeric_hosts = false
          @key_hash_algorithm = :simple
          @store_test_data = false
          @debug = false
          @word_size = 64
          @bwlimit = 0
        end

        def execute(config, *args)
          cout = STDOUT
          status = 0
          cout.puts "setting up key resolver ..."
          resolver = Util::KeyResolver.new
          cout.puts "connecting to index ..."
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'].to_i, val['role'], key]}
            partition_size = 1+nodes.inject(-1) do |r,entry|
              node, val = entry
              i = val['partition'].to_i
              if i >= r then i else r end
            end
            if partition_size <= 0
              puts "no need to verify."
              return
            end

            cout.puts "partition_size: #{partition_size}"

            if @store_test_data && nodes.size > 0
              cout.puts "storing test data ..."
              hostname, port = nodes[0][0].split(":", 2)
              Flare::Tools::Node.open(hostname, port.to_i, config[:timeout]) do |n|
                (1..100000).each do |i|
                  n.set("KEY"+Digest::MD5.new.update(i.to_s).to_s, i.to_s)
                end
              end
            end
            
            nodes.each do |hostname_port,val|
              hostname, port = hostname_port.split(":", 2)
              partition = val['partition'].to_i
              Flare::Tools::Node.open(hostname, port.to_i, config[:timeout]) do |n|
                cout.write "checking #{hostname_port} ... "
                msg = "OK"
                interruptible do
                  count = 0
                  cout.write "keydump ... "
                  n.dumpkey(partition, partition_size) do |key|
                    next if key.nil?
                    type = @key_hash_algorithm
                    p = resolver.resolve(get_key_hash_value(key, type, @word_size), partition_size)
                    count += 1
                    if p != partition then
                      cout.puts "failed: the partition for #{key} is #{p} but it was dumpped from #{partition}."
                      status = 1
                      msg = "NG"
                    end
                    false
                  end
                  cout.write "#{count} entries. "
                  count = 0
                  cout.write "dump ... "
                  n.dump(0, partition, partition_size, @bwlimit) do |data, key, flag, len, version, expire|
                    next if key.nil?
                    type = @key_hash_algorithm
                    p = resolver.resolve(get_key_hash_value(key, type, @word_size), partition_size)
                    count += 1
                    if p != partition then
                      cout.puts "failed: the partition for #{key} is #{p} but it was dumpped from #{partition}."
                      status = 1
                      msg = "NG"
                    end
                    false
                  end
                  cout.write "#{count} entries. "
                end
                cout.write "#{msg}\n"
              end
            end
            
            # end of connection
          end
          status
        end
        
      end
    end
  end
end

