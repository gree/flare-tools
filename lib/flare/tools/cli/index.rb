# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'rexml/document'
require 'flare/tools/stats'
require 'flare/tools/cli/sub_command'
require 'flare/util/conversion'
require 'rexml/document'

module Flare
  module Tools
    module Cli
      class Index < SubCommand
        include Flare::Util::Conversion
        
        myname :index
        desc   "print the index XML document from a cluster information."
        usage  "index"

        States = { "active" => '0', "prepare" => '1', "down" => '2', "ready" => '3' }
        Roles = { "master" => '0', "slave" => '1', "proxy" => '2' }

        def setup(opt)
          opt.on('-t', '--transitive',            "outputs transitive xml") {@formatter = REXML::Formatters::Pretty}
        end

        def initialize
          @formatter = REXML::Formatters::Default
        end
  
        def execute(config, *args)
          Flare::Tools::Stats.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)

            doc = REXML::Document.new
            doc << REXML::XMLDecl.new('1.0', 'UTF-8') 
            
            puts '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
            puts '<!DOCTYPE boost_serialization>'
            puts '<boost_serialization signature="serialization::archive" version="4">'

            item_id = {"class_id"=>"1", "tracking_level"=>"0", "version"=>"0"}
            second_id = {"class_id"=>"2", "tracking_level"=>"0", "version"=>"0"}

            node_map = doc.add_element("node_map", {"class_id"=>"0", "tracking_level"=>"0", "version"=>"0"})
            node_map.add_element('count').add_text("2")
            node_map.add_element("item_version").add_text("0")
            nodes.each do |k,v|
              node_server_name, node_server_port = k.split(':')
              node_role = v['role']
              node_state = v['state']
              node_partition = v['partition']
              node_balance = v['balance']
              node_thread_type = v['thread_type']
              item = node_map.add_element("item", item_id)
              item_id = {}
              item.add_element("first").add_text(k)
              second = item.add_element("second", second_id)
              second_id = {}
              second.add_element("node_server_name").add_text(node_server_name)
              second.add_element("node_server_port").add_text(node_server_port)
              second.add_element("node_role").add_text(Roles[node_role])
              second.add_element("node_state").add_text(States[node_state])
              second.add_element("node_partition").add_text(node_partition)
              second.add_element("node_balance").add_text(node_balance)
              second.add_element("node_thread_type").add_text(node_thread_type)
            end
            xml = ''
            formatter = @formatter.new
            formatter.write(doc.root, xml)
            puts xml
          end
        
          return 0
        end
      end
    end
  end
end

