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

def init z, path
  path_cluster = ""
  path.split('/').each do |e|
    unless e.empty?
      path_cluster += "/#{e}"
      z.create(:path => path_cluster)
    end
  end
  z.create(:path => "#{path_cluster}/index")
  z.create(:path => "#{path_cluster}/index/lock")
  z.create(:path => "#{path_cluster}/index/primary")
  z.create(:path => "#{path_cluster}/index/servers")
  z.create(:path => "#{path_cluster}/index/nodemap")
  z.create(:path => "#{path_cluster}/index/meta")
end

def init z, path
  z.delete(:path => path)
end

def nodemap z, path
  result = z.get(:path => "#{path}/index/nodemap")
  if result[:rc] == 0
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
  raise "failed to set nodemap (#{rc})" if rc != 0
end

def execute(subc, args, options)
  scheme, userinfo, host, port, registry, path, opaque, query, flagment = URI.split(options[:indexdb])
  # p scheme, userinfo, host, port, registry, path, opaque, query, flagment

  z = case scheme
      when "zookeeper"
        z = Zookeeper.new("#{host}:#{port}")
      else
        raise "invalid scheme: #{scheme}"
      end
  
  case subc
  when "set-nodemap"
    set_nodemap z, path
  when "nodemap"
    nodemap z, path
  when "init"
    init z, path
  when "destroy"
    destroy z, path
  end
  z.close
end

options = {
  :indexdb => 'zookeeper://localhost:2181/ckvs/cluster/mycluster'
}

opt = OptionParser.new
opt.on('-i URI', '--index-db=URI') {|v|
  options[:indexdb] = v
}

opt.parse!(ARGV)

subc = ARGV.shift
args = ARGV.dup

execute(subc, args, options)
