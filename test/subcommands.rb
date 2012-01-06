
require 'test/unit'
require 'flare/tools'
require 'flare/tools/cli'
require 'flare/test/cluster'

module Subcommands

  def ping(*args)
    subc = instantiate(Flare::Tools::Cli::Ping, args)
    subc.execute(@config.merge({:command => 'ping'}), *args)
  end
  
  def list(*args)
    subc = instantiate(Flare::Tools::Cli::List, args)
    subc.execute(@config.merge({:command => 'list'}))
  end

  def stats(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Stats.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'stats'}), *args)
  end

  def down(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Down.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'down'}), *args)
  end

  def activate(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Activate.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'activate'}), *args)
  end

  def slave(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Slave.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'slave'}), *args)
  end

  def balance(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Balance.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'balance'}), *args)
  end
  
  def reconstruct(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Reconstruct.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'reconstruct'}), *args)
  end

  def index(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Index.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'index'}))
  end

  def remove(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Remove.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'remove'}), *args)
  end

  def master(*args)
    opt = OptionParser.new
    subc = Flare::Tools::Cli::Master.new
    subc.setup(opt)
    opt.parse!(args)
    subc.execute(@config.merge({:command => 'master'}), *args)
  end
  
end
