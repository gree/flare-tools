
require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'

module Subcommands

  S_OK = 0
  S_NG = 1

  def instantiate(cls, args)
    subc = cls.new
    subc.setup
    subc.optp.parse!(args)
    subc
  end

  def ping(*args)
    subc = instantiate(Flare::Tools::Cli::Ping, args)
    subc.execute(@config.merge({:command => 'ping'}), args)
  end
  
  def list(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    subc = instantiate(Flare::Tools::Cli::List, args)
    subc.execute(@config.merge({:command => 'list'}), args)
  end

  def stats(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    subc = instantiate(Flare::Tools::Cli::Stats, args)
    subc.execute(@config.merge({:command => 'stats'}), args)
  end

  def down(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Down, args)
    subc.execute(@config.merge({:command => 'down'}), args)
  end

  def activate(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Activate, args)
    subc.execute(@config.merge({:command => 'activate'}), args)
  end

  def slave(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Slave, args)
    subc.execute(@config.merge({:command => 'slave'}), args)
  end

  def balance(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Balance, args)
    subc.execute(@config.merge({:command => 'balance'}), args)
  end
  
  def reconstruct(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Reconstruct, args)
    subc.execute(@config.merge({:command => 'reconstruct'}), args)
  end

  def index(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    subc = instantiate(Flare::Tools::Cli::Index, args)
    subc.execute(@config.merge({:command => 'index'}), args)
  end

  def remove(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Remove, args)
    subc.execute(@config.merge({:command => 'remove'}), args)
  end

  def master(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Master, args)
    subc.execute(@config.merge({:command => 'master'}), args)
  end

  def dump(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    subc = instantiate(Flare::Tools::Cli::Dump, args)
    subc.execute(@config.merge({:command => 'dump'}), args)
  end
  
  def dumpkey(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    subc = instantiate(Flare::Tools::Cli::Dumpkey, args)
    subc.execute(@config.merge({:command => 'dumpkey'}), args)
  end
  
  def verify(*args)
    args << "--index-server" << @index_server_hostname
    args << "--index-server-port" << @index_server_port.to_s unless @index_server_port.nil?
    puts "args: "+args.join(' ')
    subc = instantiate(Flare::Tools::Cli::Verify, args)
    subc.execute(@config.merge({:command => 'verify'}), args)
  end
  
  def restore(*args)
    subc = instantiate(Flare::Tools::Cli::Restore, args)
    subc.execute(@config.merge({:command => 'restore'}), args)
  end
  
end
