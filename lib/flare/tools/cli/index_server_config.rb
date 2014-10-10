require 'flare/tools/index_server'
require 'flare/entity/server'
require 'flare/util/logging'

module Flare; end
module Flare::Tools; end
module Flare::Tools::Cli; end
module Flare::Tools::Cli::IndexServerConfig
  include Flare::Util::Constant
  include Flare::Util::Logging
  FLARE_INDEX_SERVERS = "FLARE_INDEX_SERVERS"
  FLARE_INDEX_SERVER = "FLARE_INDEX_SERVER"
  Entity = Flare::Entity

  private

  def parse_index_server(config, rest)
    if @cluster
      @index_server_entity = get_index_server_from_cluster(@cluster)
    else
      @index_server_entity =
        get_index_server_from_nodekeys(rest) ||
        get_index_server_name_and_port(Entity::Server.new(@index_server_host, @index_server_port))
    end

    return unless @index_server_entity

    config[:index_server_hostname] = @index_server_entity.host
    config[:index_server_port] = @index_server_entity.port
  end

  # @return [Flare::Entity::Server | nil]
  def get_index_server_from_cluster(name, envname = FLARE_INDEX_SERVERS)
    return nil if name.nil?
    if ENV.has_key? envname
      clusters = ENV[envname].split(';').map{|s| s.split(':')}
      clusters.each do |cluster_name,index_name,index_port|
        return Entity::Server.new(index_name, index_port) if cluster_name == name
      end
    end
    return nil
  end

  # @return [Flare::Entity::Server | nil]
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
            Entity::Server.new(index_name, index_port)
          else
            nil
          end
        end
        return ret unless ret.nil?
      end
    end
    nil
  rescue => e
    debug(e.message)
    nil
  end

  # @param [Flare::Entity::Server] index_server
  # @return [Flare::Entity::Server]
  def get_index_server_name_and_port(index_server, envname = FLARE_INDEX_SERVER)
    env_ihostname = nil
    env_iport = nil
    if ENV.has_key? envname
      env_ihostname, env_iport = ENV[envname].split(':')
    end
    ihostname, iport = index_server.host.split(':') unless index_server.host.nil?
    ihostname = ihostname || env_ihostname || DefaultIndexServerName
    if iport && index_server.port
      raise "--index-server-port option isn't allowed."
    else
      iport = index_server.port || env_iport || DefaultIndexServerPort if iport.nil?
    end
    Entity::Server.new(ihostname, iport)
  end
end
