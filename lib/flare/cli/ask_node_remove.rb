# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

require 'flare/util/interruption'

module Flare; end
module Flare::Cli; end
module Flare::Cli::AskNodeRemove

  # @param [Flare::Entity::Server] server
  # @param [Flare::Tools::Cluster::NodeStat] node_stat
  # @return [Boolean] approved
  def ask_node_remove(server, node_stat)
    STDERR.print "remove the node from a cluster (node=#{server}, role=#{node_stat.role}, state=#{node_stat.state}) (y/n): "
    interruptible {
      STDIN.gets.chomp.upcase == "Y"
    }
  end

end
