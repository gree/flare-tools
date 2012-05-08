
require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'

module Subcommands

  S_OK = 0
  S_NG = 1

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
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Down, args)
    subc.execute(@config.merge({:command => 'down'}), *args)
  end

  def activate(*args)
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Activate, args)
    subc.execute(@config.merge({:command => 'activate'}), *args)
  end

  def slave(*args)
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Slave, args)
    subc.execute(@config.merge({:command => 'slave'}), *args)
  end

  def balance(*args)
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Balance, args)
    subc.execute(@config.merge({:command => 'balance'}), *args)
  end
  
  def reconstruct(*args)
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Reconstruct, args)
    subc.execute(@config.merge({:command => 'reconstruct'}), *args)
  end

  def index(*args)
    subc = instantiate(Flare::Tools::Cli::Index, args)
    subc.execute(@config.merge({:command => 'index'}))
  end

  def remove(*args)
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Remove, args)
    subc.execute(@config.merge({:command => 'remove'}), *args)
  end

  def master(*args)
    args << "--force"
    subc = instantiate(Flare::Tools::Cli::Master, args)
    subc.execute(@config.merge({:command => 'master'}), *args)
  end

  def dump(*args)
    subc = instantiate(Flare::Tools::Cli::Dump, args)
    subc.execute(@config.merge({:command => 'dump'}), *args)
  end
  
  def dumpkey(*args)
    subc = instantiate(Flare::Tools::Cli::Dumpkey, args)
    subc.execute(@config.merge({:command => 'dumpkey'}), *args)
  end
  
  def verify(*args)
    puts "args: "+args.join(' ')
    subc = instantiate(Flare::Tools::Cli::Verify, args)
    subc.execute(@config.merge({:command => 'verify'}), *args)
  end
  
  def restore(*args)
    subc = instantiate(Flare::Tools::Cli::Restore, args)
    subc.execute(@config.merge({:command => 'restore'}), *args)
  end
  
end
