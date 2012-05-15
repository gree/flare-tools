# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/index_server'

module Flare
  module Tools
    module Cli
      module CliUtil
        FLARE_INDEX_SERVERS = "FLARE_INDEX_SERVERS"
        FLARE_INDEX_SERVER = "FLARE_INDEX_SERVER"

        def get_index_server_from_cluster(name, envname = FLARE_INDEX_SERVERS)
          return nil if name.nil?
          if ENV.has_key? envname
            clusters = ENV[envname].split(';').map{|s| s.split(':')}
            clusters.each do |cluster_name,index_name,index_port|
              return [index_name, index_port] if cluster_name == name
            end
          end
          return nil
        end

        def get_index_server_from_nodekeys(dnodekeys, envname = FLARE_INDEX_SERVERS)
          nodekeys = []
          return nil if dnodekeys.empty?
          dnodekeys.each do |n|
            l = n.split(':')
            return nil if l.size < 2
            nodekeys << "#{l[0]}:#{l[1]}"
          end
          if ENV.has_key? envname
            clusters = ENV[envname].split(';').map{|s| s.split(':')}
            clusters.each do |cluster_name,index_name,index_port|
              ret = Flare::Tools::IndexServer.open(index_name, index_port.to_i) do |s|
                cluster_nodekeys = s.stats_nodes.map {|x| x[0]}
                included = true
                nodekeys.each do |nodekey|
                  included = false unless cluster_nodekeys.include? nodekey
                end
                if included
                  [index_name, index_port]
                else
                  nil
                end
              end
              return ret unless ret.nil?
            end
          end
          nil
        rescue => e
          nil
        end

        def get_index_server_name_and_port(index_server_hostname, index_server_port, envname = FLARE_INDEX_SERVER)
          env_ihostname = nil
          env_iport = nil
          if ENV.has_key? envname
            env_ihostname, env_iport = ENV[envname].split(':')
          end
          ihostname, iport = index_server_hostname.split(':') unless index_server_hostname.nil?
          ihostname = ihostname || env_ihostname || DefaultIndexServerName
          if iport && index_server_port
            raise "--index-server-port option isn't allowed."
          else
            iport = index_server_port || env_iport || DefaultIndexServerPort if iport.nil?
          end
          [ihostname, iport]
        end

      end
    end
  end
end

