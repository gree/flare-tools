# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

module Flare; end
module Flare::Operation; end
module Flare::Operation::NodeRemove

  # @param [Flare::Tools::Cluster::NodeStat] node_stat
  # @return [Boolean]
  def node_can_remove_safely?(node_stat)
    node_stat.proxy? && node_stat.down?
  end

  # @param [Flare::Tools::IndexServer] client  index server client
  # @param [Flare::Entity::Server] server
  # @param [Integer] retry_count
  # @param [Boolean] dry_run
  # @return [Boolean] succeeded
  def node_remove(client, server, retry_count, dry_run)
    (retry_count + 1).times do
      resp = false
      info "removing #{server}."
      resp = client.node_remove(server.host, server.port) unless dry_run
      if resp
        return true
      end
    end
    return false
  end

end
