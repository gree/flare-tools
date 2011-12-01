# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/stats'
require 'flare/tools/cli/sub_command'
require 'flare/util/conversion'

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
          opt.on('--output=[FILE]',            "outputs index to a file") {|v|@output = v}
        end

        def initialize
          super
          @output = nil
        end

        def serattr(x)
          return "" if x.nil?
          " class_id=\"#{x['class_id']}\" tracking_level=\"#{x['tracking_level']}\" version=\"#{x['version']}\""
        end
  
        def execute(config, *args)
          Flare::Tools::Stats.open(config[:index_server_hostname], config[:index_server_port], config[:timeout]) do |s|
            nodes = s.stats_nodes.sort_by{|key, val| [val['partition'], val['role'], key]}
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)
            thread_type = 0

            node_map_id = {"class_id"=>"0", "tracking_level"=>"0", "version"=>"0"}
            item_id = {"class_id"=>"1", "tracking_level"=>"0", "version"=>"0"}
            second_id = {"class_id"=>"2", "tracking_level"=>"0", "version"=>"0"}

            output =<<"EOS"
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<!DOCTYPE boost_serialization>
<boost_serialization signature="serialization::archive" version="4">
<node_map#{serattr(node_map_id)}>
\t<count>#{nodes.size}</count>
\t<item_version>0</item_version>
EOS
            nodes.each do |k,v|
              node_server_name, node_server_port = k.split(':')
              node_role = Roles[v['role']]
              node_state = States[v['state']]
              node_partition = v['partition']
              node_balance = v['balance']
              node_thread_type = v['thread_type'].to_i

              output +=<<"EOS"
\t<item#{serattr(item_id)}>
\t\t<first>#{k}</first>
\t\t<second#{serattr(second_id)}>
\t\t\t<node_server_name>#{node_server_name}</node_server_name>
\t\t\t<node_server_port>#{node_server_port}</node_server_port>
\t\t\t<node_role>#{node_role}</node_role>
\t\t\t<node_state>#{node_state}</node_state>
\t\t\t<node_partition>#{node_partition}</node_partition>
\t\t\t<node_balance>#{node_balance}</node_balance>
\t\t\t<node_thread_type>#{node_thread_type}</node_thread_type>
\t\t</second>
\t</item>
EOS
              item_id = nil
              second_id  = nil
              thread_type = node_thread_type+1 if node_thread_type >= thread_type
            end
            output +=<<"EOS"
</node_map>
<thread_type>#{thread_type}</thread_type>
</boost_serialization>
EOS
            if @output.nil?
              info output
            else
              open(@output, "w") do |f|
                f.write(output)
              end
            end
          end
        
          S_OK
        end
      end
    end
  end
end

