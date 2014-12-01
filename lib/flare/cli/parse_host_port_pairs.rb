# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

require 'flare/entity/server'

module Flare; end
module Flare::Cli; end
module Flare::Cli::ParseHostPortPairs
  Entity = Flare::Entity

  # @param [String] args
  # @return [Array]    server entities
  # @return [nil]
  def parse_host_port_pairs(args)
    servers = args.map {|x| x.split(':')}
    servers.each do |x|
      if x.size != 2
        error "invalid argument '#{x.join(':')}'. it must be hostname:port."
        return nil
      end
    end
    servers.map do |s|
      Entity::Server.new(s[0], s[1])
    end
  end

end
