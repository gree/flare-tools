# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/cli/dispatch'

module Flare; end
module Flare::Tools; end
module Flare::Tools::Cli; end
class Flare::Tools::Cli::FlareAdmin
  def main
    subcommand = ARGV[0]
    argv = ARGV[1..-1]

    # We should clear ARGV to use (Kernel#)gets.
    # see also: http://stackoverflow.com/questions/1883925/kernelgets-attempts-to-read-file-instead-of-standard-input
    ARGV.clear
    exit Flare::Tools::Cli::Dispatch.new.main(subcommand, argv, true)
  end
end


# execute!
Flare::Tools::Cli::FlareAdmin.new.main
