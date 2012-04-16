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
          opt.on('--use-test-data',                        "store test data") {|v| @use_test_data = true}
          opt.on('--debug',                                "debug mode") {|v| @debug = true}
          opt.on('--32bit',                                "32bit mode") {|v| @word_size = 32}
          opt.on('--verbose',                              "verbose mode") {|v| @verbose = true}
        end

        def initialize
          super
          @machine_word_width
          @numeric_hosts = false
          @key_hash_algorithm = :simple
          @use_test_data = false
          @debug = false
          @word_size = 64
          @bwlimit = 0
          @verbose = false
        end

        S_ERROR = 1
        S_OK = 0

        def execute(config, *args)
          keys = {}
          cout = STDOUT
          status = S_OK
          cout.puts "setting up key resolver ..."
          resolver = Util::KeyResolver.new
          cout.puts "connecting to index ..."
          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'].to_i, val['role'], key]}

            # check node list size
            if nodes.size == 0
              cout.puts "no nodes"
              return S_ERROR
            end
            hostname0, port0 = nodes[0][0].split(":", 2)

            # partition size
            partition_size = 1+nodes.inject(-1) do |r,entry|
              node, val = entry
              i = val['partition'].to_i
              if i >= r then i else r end
            end
            if partition_size <= 0
              cout.puts "no need to verify."
              return S_ERROR
            end
            cout.puts "partition_size: #{partition_size}"

            if @use_test_data
              cout.puts "storing test data ..."
              Flare::Tools::Node.open(hostname0, port0.to_i, config[:timeout]) do |n|
                (1..100000).each do |i|
                  key = ".test."+Digest::MD5.new.update(i.to_s).to_s
                  n.set(key, i.to_s)
                  keys[key] = :not_found
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
                      status = S_ERROR
                      msg = "NG"
                    else
                      keys[key] = :found
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
                      status = S_ERROR
                      msg = "NG"
                    end
                    false
                  end
                  cout.write "#{count} entries. "
                end # interruptible
                cout.write "#{msg}\n"
              end # Node.open
            end # nodes.each

            if @use_test_data && keys.size > 0
              # check total result
              remain = 0
              keys.each do |k,state|
                if state != :found
                  cout.puts "failed: not found '#{k}'" if @verbose
                  remain += 1
                end
              end
              cout.puts "failed: not found #{remain} keys" if remain > 0

              # delete
              Flare::Tools::Node.open(hostname0, port0.to_i, config[:timeout]) do |n|
                keys.each do |k,v|
                  n.delete(k)
                end
              end
            end

            # end of connection
          end
          if status == S_OK
            cout.puts "OK"
          else
            cout.puts "NG"
          end
          status
        end
        
      end
    end
  end
end

