require 'optparse'
require 'resolv'
require 'flare/tools'
require 'flare/util/logging'
require 'flare/util/conversion.rb'
require 'flare/tools/cli/option'
require 'flare/util/constant'

module Flare; end
module Flare::Tools; end
module Flare::Tools::Cli; end
class Flare::Tools::Cli::Dispatch
  include Flare::Util::Logging
  include Flare::Tools::Cli::Option
  include Flare::Util::Constant
  Cli = Flare::Tools::Cli

  attr_accessor :subcommands

  def initialize
    @subcommands = {
      'activate'    => Cli::Activate,
      'balance'     => Cli::Balance,
      'down'        => Cli::Down,
      'dump'        => Cli::Dump,
      'dumpkey'     => Cli::Dumpkey,
      'index'       => Cli::Index,
      'list'        => Cli::List,
      'master'      => Cli::Master,
      'part'        => Cli::Part,
      'ping'        => Cli::Ping,
      'reconstruct' => Cli::Reconstruct,
      'remove'      => Cli::Remove,
      'restore'     => Cli::Restore,
      'slave'       => Cli::Slave,
      'stats'       => Cli::Stats,
      'summary'     => Cli::Summary,
      'threads'     => Cli::Threads,
      'verify'      => Cli::Verify,
    }
  end

  def main(subcommand_name, argv, as_subcommand)
    prepare
    _main(subcommand_name, argv, as_subcommand)
  rescue => e
    level = 1
    error(e.to_s)
    e.backtrace.each do |line|
      error("  %3s: %s" % [level, line])
      level += 1
    end
    raise e if $DEBUG
    STATUS_NG
  end

private

  def prepare
    Thread.abort_on_exception = true
  end

  def _main(subcommand_name, argv, as_subcommand)
    @subcommand_name = subcommand_name

    subc = dispatch_subcommmand(@subcommand_name)
    unless subc
      show_undefined_command_error(as_subcommand)
      exit STATUS_NG
    end
    set_banner subc.optp, as_subcommand
    config = {
      :command => File.basename($PROGRAM_NAME),
    }
    subc.execute_subcommand(config, argv)
  end

  def dispatch_subcommmand(name)
    return nil unless @subcommands.include?(name)
    @subcommands[name].new
  end

  def set_banner(optp, as_subcommand)
    if as_subcommand
      optp.banner = "#{Flare::Tools::TITLE}\nUsage: flare-#{@subcommand_name} [options]"
    else
      optp.banner = "#{Flare::Tools::TITLE}\nUsage: flare-admin #{@subcommand_name} [options]"
    end
  end

  def show_undefined_command_error(as_subcommand)
    if as_subcommand
      error "unknown subcommand '#{@subcommand_name}'"
      puts "subcommands:"
      @subcommands.each do |name, klass|
        sc = klass.new
        sc.setup
        sc.optp.banner = "[#{klass.to_s}] " + klass.desc
        sc.optp.separator("  Usage: flare-admin " + klass.usage)
        puts sc.optp.help
      end
    else
      puts "unknown command"
    end
  end
end
