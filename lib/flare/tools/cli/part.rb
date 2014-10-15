# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/stats'
require 'flare/tools/index_server'
require 'flare/tools/common'
require 'flare/util/conversion'
require 'flare/util/constant'
require 'flare/tools/cli/sub_command'
require 'flare/tools/cli/slave'
require 'flare/tools/cli/master'
require 'flare/tools/cli/index_server_config'

module Flare
  module Tools
    module Cli
      class Part < SubCommand
        include Flare::Util::Conversion
        include Flare::Util::Constant
        include Flare::Tools::Common
        include Flare::Tools::Cli::IndexServerConfig

        myname :part
        desc   "set the master of a partition."
        usage  "master [hostname:port:balance:partition] ..."

        def setup
          super
          set_option_index_server
          set_option_force
          @optp.on('--retry=COUNT',    "retry count"                         ) {|v| @retry = v.to_i}
        end

        def initialize
          super
          @force = false
          @retry = nil
        end

        def execute(config, args)
          parse_index_server(config, args)
          return S_NG if args.size < 1

          hosts = args.map {|x| x.to_s.split(':')}
          hosts.each do |x|
            if x.size != 4
              puts "invalid argument '#{x.join(':')}'."
              return S_NG
            end
          end

          masters = []
          slaves = []

          Flare::Tools::IndexServer.open(config[:index_server_hostname], config[:index_server_port], @timeout) do |s|
            cluster = Flare::Tools::Cluster.new(s.host, s.port, s.stats_nodes)

            partitions = {}
            hosts.each do |hostname,port,balance,partition|
              partitions[partition] = [] unless partitions.has_key? partition
              partitions[partition] << "#{hostname}:#{port}:#{balance}:#{partition}"
            end

            partitions.sort_by {|p,nodes| p.to_i }.each do |p,nodes|
              masters << nodes.shift
            end

            partitions.each do |p,nodes|
              slaves.concat nodes
            end
          end

          puts "master:"
          begin
            opt = OptionParser.new
            subc = Flare::Tools::Cli::Master.new
            args = masters
            args << "--force" if @force
            args << "--activate"
            subc.execute_subcommand(config, args)
          end

          puts "slaves:"
          begin
            opt = OptionParser.new
            subc = Flare::Tools::Cli::Slave.new
            args = slaves
            args << "--force" if @force
            args << "--retry=#{@retry}" unless @retry.nil?
            subc.execute_subcommand(config, args)
          end

          S_OK
        end # execute()

      end
    end
  end
end
