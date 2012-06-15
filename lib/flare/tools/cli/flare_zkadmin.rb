# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'rubygems'
require 'optparse'
require 'uri'
require 'zookeeper'
require 'flare/tools/cluster'

uri = "zookeeper://localhost:2181/ckvs/clusters/mycluster"
path = nil
indexdb_elements = []

ZOK = Zookeeper::ZOK

def init z, path
  puts "initializing #{path}"
  path_cluster = ""
  path.split('/').each do |e|
    unless e.empty?
      path_cluster += "/#{e}"
      z.create(:path => path_cluster)
    end
  end
  
  path_index = "#{path_cluster}/index"
  r = z.create(:path => "#{path_index}")
  raise "already initialized." unless r[:rc] == ZOK

  z.create(:path => "#{path_index}/lock")
  z.create(:path => "#{path_index}/primary")
  z.create(:path => "#{path_index}/servers")
  z.create(:path => "#{path_index}/nodemap")

  path_meta = "#{path_index}/meta"
  z.create(:path => path_meta)
  entries = [['partition-size', '1024'],
             ['key-hash-algorithm', 'crc32'],
             ['partition-type', 'modular'],
             ['partition-modular-hint', '1'],
             ['partition-modular-virtual', '65536']]
  entries.each do |k,v|
    r = z.create(:path => "#{path_meta}/#{k}", :data => v)
  end

  clear_nodemap z, path
end

def destroy z, path
  result = z.get_children(:path => path)
  raise "failed to fetch child nodes." if result[:rc] != ZOK
  result[:children].each do |entry|
    destroy z, "#{path}/#{entry}"
  end
  z.delete(:path => path)
end

def nodemap z, path
  result = z.get(:path => "#{path}/index/nodemap")
  if result[:rc] == ZOK
    xml = result[:data]
    unless xml.nil?
      cluster = Flare::Tools::Cluster.build xml
      print cluster.serialize
    end
  end
end

def set_nodemap z, path
  path_nodemap = "#{path}/index/nodemap"
  xml = ""
  while line = STDIN.gets
    xml += line
  end
  result = z.set(:path => path_nodemap, :data => xml)
  rc = result[:rc]
  raise "failed to set nodemap (#{rc})" if rc != ZOK
end

def clear_nodemap z, path
  path_nodemap = "#{path}/index/nodemap"
  xml = <<EOS
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<!DOCTYPE boost_serialization>
<boost_serialization signature="serialization::archive" version="4">
<node_map class_id="0" tracking_level="0" version="0">
	<count>0</count>
	<item_version>0</item_version>
</node_map>
<thread_type>16</thread_type>
</boost_serialization>
EOS
  STDOUT.print "do you really want to clear nodemap? (y/n):"
  STDOUT.flush
  if gets.chomp.upcase == 'Y'
    result = z.set(:path => path_nodemap, :data => xml)
    rc = result[:rc]
    raise "failed to clear nodemap (#{rc})" if rc != ZOK
  end
end

def servers z, path
  result = z.get(:path => "#{path}/index/servers")
  if result[:rc] == ZOK
    puts result[:data].split(',').join(' ')
  end
end

def set_servers z, path, *args
  path_servers = "#{path}/index/servers"
  result = z.set(:path => path_servers, :data => args.join(','))
  rc = result[:rc]
  raise "failed to set nodemap (#{rc})" if rc != ZOK
end

def show z, path
  path_index = "#{path}/index"
  path_lock = "#{path_index}/lock"
  path_servers = "#{path_index}/servers"
  path_nodemap = "#{path_index}/nodemap"
  path_primary = "#{path_index}/primary"
  path_meta = "#{path_index}/meta"
  result = z.get_children(:path => path_index)
  raise "failed to fetch child nodes." if result[:rc] != ZOK
  result[:children].each do |entry|
    puts "#{entry}:"
    case entry
    when "lock"
      r = z.get_children(:path => path_lock)
      if r[:rc] == ZOK
        r[:children].sort_by {|n| n.split('-').last}.each do |m|
          puts "\t#{m}"
        end
      end
    when "primary"
      r = z.get(:path => path_primary)
      if r[:rc] == ZOK && !r[:data].nil?
        puts "\t#{r[:data]}"
      end
    when "servers"
      r = z.get(:path => path_servers)
      puts "\t#{r[:data]}" if r[:rc] == ZOK && !r[:data].nil?
    when "nodemap"
      r = z.get(:path => path_nodemap)
      if r[:rc] == ZOK
        xml = r[:data]
        unless xml.nil?
          cluster = Flare::Tools::Cluster.build xml
          cluster.nodekeys.each do |nodekey|
            n = cluster.node_stat(nodekey)
            p = if n.partition == -1 then "-" else n.partition end
            m = "#{n.server_name}:#{n.server_port}:#{n.balance}:#{p}"
            puts "\t#{m} #{n.role} #{n.state} #{n.thread_type}"
          end
        end
      end
    when "meta"
      r = z.get_children(:path => path_meta)
      if r[:rc] == ZOK
        r[:children].each do |m|
          r2 = z.get(:path => "#{path_meta}/#{m}")
          puts "\t#{m} #{r2[:data]}" if r2[:rc] == ZOK
        end
      end
    else
      puts "\tunknown entry"
    end
  end
end

def execute(subc, args, options)
  scheme, userinfo, host, port, registry, path, opaque, query, flagment = URI.split(options[:indexdb])
  # p scheme, userinfo, host, port, registry, path, opaque, query, flagment

  z = case scheme
      when "zookeeper"
        Zookeeper.new("#{host}:#{port}")
      else
        raise "invalid scheme: #{scheme}"
      end
  
  case subc
  when "set-servers"
    set_servers z, path, *args
  when "servers"
    servers z, path
  when "set-nodemap"
    set_nodemap z, path
  when "clear-nodemap"
    clear_nodemap z, path
  when "nodemap"
    nodemap z, path
  when "init"
    init z, path
  when "destroy"
    destroy z, path
  when "show"
    show z, path
  end
  z.close
end

options = {
  :indexdb => 'zookeeper://localhost:2181/ckvs/clusters/mycluster'
}

opt = OptionParser.new
opt.on('-i URI', '--index-db=URI') {|v|
  options[:indexdb] = v
}

opt.parse!(ARGV)

subc = ARGV.shift
args = ARGV.dup

execute(subc, args, options)
