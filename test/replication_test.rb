#!/usr/bin/ruby
# -*- coding: utf-8; -*- 

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/tools'
require 'flare/test/cluster'

class ReplicationTest < Test::Unit::TestCase
  include Flare::Tools::Common

  def setup
    @flare_cluster = Flare::Test::Cluster.new('test')
    sleep 1 # XXX
    @node_servers = ['node1', 'node2', 'node3', 'node4', 'node5', 'node6'].map {|name| @flare_cluster.create_node(name)}
    sleep 1 # XXX
    @flare_cluster.wait_for_ready
    @config = {
      :command => 'dummy',
      :index_server_hostname => @flare_cluster.indexname,
      :index_server_port => @flare_cluster.indexport,
      :dry_run => false,
      :timeout => 10
    }
  end

  def test_replication
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    Flare::Tools::Node.open(@flare_cluster.indexname, @flare_cluster.indexport, 10) do |s|
      puts string_of_nodelist(s.stats_nodes)
      node = @node_servers[1]
      puts "throwing requests to #{node.hostname}:#{node.port}."
      Flare::Tools::Node.open(node.hostname, node.port, 10) do |n|
        fmt = "key%010.10d"
        (0...10).each do |i|
          n.set(fmt % i, "All your base are belong to us.")
        end
      end
      puts string_of_nodelist(s.stats_nodes)
    end
  end

  def parallel(*args, &block)
    args.map do |arg|
      Thread.new do
        block.call(arg)
      end
    end
  end

  def test_replication_consistent
    replication_consistent(false)
  end

  def test_replication_consistent_noreply
    replication_consistent(true, 0.1)
  end

  def replication_consistent(noreply, wait = 0)
    @flare_cluster.prepare_master_and_slaves(@node_servers)
    Flare::Tools::Node.open(@flare_cluster.indexname, @flare_cluster.indexport, 10) do |s|
      puts string_of_nodelist(s.stats_nodes)
      ntry = 256
      nparallel = 128
      nloop = 32
      entries = (0...nparallel).map { |i|
        {
          :index => i,
          :command_queue => Queue.new,
          :hostname => @node_servers[0].hostname,
          :port => @node_servers[0].port,
          :result_queue => Queue.new,
          :backlog_queue => Queue.new
        }
      }
      puts "creating threads..."
      entries.each { |entry| entry[:command_queue].enq("start") }
      threads = parallel(*entries) do |entry|
        Flare::Tools::Node.open(entry[:hostname], entry[:port], 10) do |n|
          while command = entry[:command_queue].deq
            case command
            when "start"
              # puts "#{entry[:index]}:#{entry[:hostname]}:#{entry[:port]}: start"
              n.set("key", "0")
              # puts "#{entry[:index]}:#{entry[:hostname]}:#{entry[:port]}: start end"
            when "end"
              entry[:result_queue].enq("terminated")
              break
            when "execute"
              # puts "#{entry[:index]}:#{entry[:hostname]}:#{entry[:port]}: begin"
              (0...nloop).each do |i|
                if i%10 == 0
                  print "."
                  n.delete("key")
                  n.set("key", "111")
                elsif i%10 == 1
                  n.decr("key", "1")
                else
                  n.incr("key", "1")
                end
                Thread.pass
              end
              # puts "#{entry[:index]}:#{entry[:hostname]}:#{entry[:port]}: end"
              entry[:result_queue].enq("finished")
            when "execute_noreply"
              # puts "#{entry[:hostname]}:#{entry[:port]}: begin"
              (0...nloop).each do |i|
                # print "(#{entry[:index]})"
                case rand(10)
                when 0
                  n.delete_noreply("key")
                when 1
                  n.set_noreply("key", rand(100).to_s)
                when 2
                  n.decr_noreply("key", "1")
                else
                  n.incr_noreply("key", "1")
                end
                # Thread.pass
              end
              # puts "#{entry[:hostname]}:#{entry[:port]}: end"
              entry[:result_queue].enq("finished")
            end
          end
        end
      end

      nodes = @node_servers.map do |node|
        Flare::Tools::Node.open(node.hostname, node.port, 10)
      end

      (0...ntry).each do |n|
        entries.each {|entry|
          command = if noreply then "execute_noreply" else "execute" end
          entry[:command_queue].enq(command)
        }
        print "waiting(#{n})..."
        if noreply && wait > 0
          while entries[0][:result_queue].empty?
            @node_servers[0].stop
            sleep wait
            @node_servers[0].cont
            sleep wait if entries[0][:result_queue].empty?
          end
        end
        entries.map {|entry| assert_equal("finished", entry[:result_queue].deq) }
        for i in 1..5
          failed = false
          sleep wait
          results = nodes.map do |n|
            n.get("key")
          end
          slave_results = results.dup
          master_result = slave_results.shift
          slave_results.each {|r| failed = true if master_result != r}
          puts results.join(' ')
          if failed
            if i > 3
              puts "inconsistent data: master=#{master_result}\n"
            end
          else
            break
          end
        end
        slave_results.each {|r| assert_equal(master_result, r)}
      end
      entries.each {|entry| entry[:command_queue].enq("end") }
      entries.map {|entry| assert_equal("terminated", entry[:result_queue].deq)}
      threads.each do |t|
        t.join
      end
      puts string_of_nodelist(s.stats_nodes)
      puts "done."
    end
  end

end
