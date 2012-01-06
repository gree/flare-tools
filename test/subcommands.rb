
require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'

module Subcommands

  def instantiate(cls, args)
    opt = OptionParser.new
    subc = cls.new
    subc.setup(opt)
    opt.parse!(args)
    subc
  end

  def ping(*args)
    subc = instantiate(Flare::Tools::Cli::Ping, args)
    subc.execute(@config.merge({:command => 'ping'}), *args)
  end
  
  def list(*args)
    subc = instantiate(Flare::Tools::Cli::List, args)
    subc.execute(@config.merge({:command => 'list'}))
  end

  def stats(*args)
    subc = instantiate(Flare::Tools::Cli::Stats, args)
    subc.execute(@config.merge({:command => 'stats'}), *args)
  end

  def down(*args)
    subc = instantiate(Flare::Tools::Cli::Down, args)
    subc.execute(@config.merge({:command => 'down'}), *args)
  end

  def activate(*args)
    subc = instantiate(Flare::Tools::Cli::Activate, args)
    subc.execute(@config.merge({:command => 'activate'}), *args)
  end

  def slave(*args)
    subc = instantiate(Flare::Tools::Cli::Slave, args)
    subc.execute(@config.merge({:command => 'slave'}), *args)
  end

  def balance(*args)
    subc = instantiate(Flare::Tools::Cli::Balance, args)
    subc.execute(@config.merge({:command => 'balance'}), *args)
  end
  
  def reconstruct(*args)
    subc = instantiate(Flare::Tools::Cli::Reconstruct, args)
    subc.execute(@config.merge({:command => 'reconstruct'}), *args)
  end

  def index(*args)
    subc = instantiate(Flare::Tools::Cli::Index, args)
    subc.execute(@config.merge({:command => 'index'}))
  end

  def remove(*args)
    subc = instantiate(Flare::Tools::Cli::Remove, args)
    subc.execute(@config.merge({:command => 'remove'}), *args)
  end

  def master(*args)
    subc = instantiate(Flare::Tools::Cli::Master, args)
    subc.execute(@config.merge({:command => 'master'}), *args)
  end
  
end
