require 'flare/entity/server'
require 'flare/util/constant'

module Flare; end
module Flare::Tools; end
module Flare::Tools::Cli; end
module Flare::Tools::Cli::Option
  include Flare::Util::Constant

  attr_reader :optp

  def option_init
    @optp = OptionParser.new
  end

  def set_option_global
    @optp.on('-h',        '--help',     "show this message") { puts @optp.help; exit 1 }
    @optp.on(             '--debug',    "enable debug mode") { $DEBUG = true }
    @optp.on(             '--warn',     "turn on warnings")  { $-w = true }
    @optp.on(             '--log-file=LOGFILE',       "output log to LOGFILE") {|v| Flare::Util::Logging.set_logger(v)}

    @timeout ||= DefaultTimeout
    @optp.on(             '--timeout=SECOND',         "specify timeout") {|v| @timeout = v.to_i}
  end

  def set_option_index_server
    @index_server_entity ||= Flare::Entity::Server.new(nil, nil)
    @cluster ||= nil

    @optp.on('-i HOSTNAME', '--index-server=HOSTNAME',  "index server hostname(default:#{DefaultIndexServerName})") {|v| @index_server_host = v}
    @optp.on('-p PORT',     '--index-server-port=PORT', "index server port(default:#{DefaultIndexServerPort})") {|v| @index_server_port = v.to_i}
    @optp.on(               '--cluster=NAME',           "specify a cluster name") {|v| @cluster = v}
  end

  def set_option_dry_run
    @dry_run ||= false
    @optp.on('-n',          '--dry-run',                "dry run") { @dry_run = true }
  end

  def set_option_force
    @force ||= false
    @optp.on('--force', "commit changes without confirmation") { @force = true }
  end

  def parse_options(config, argv)
    begin
      rest = @optp.parse(argv)
    rescue OptionParser::ParseError => err
      puts err.message
      puts @optp.to_s
      exit STATUS_NG
    end
    rest
  end
end
