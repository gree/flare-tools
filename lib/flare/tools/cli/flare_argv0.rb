# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

require 'flare/tools/cli/dispatch'

cliname = File.basename($PROGRAM_NAME)
cliname[/flare-/] = ""
argv = ARGV.dup

# We should clear ARGV to use (Kernel#)gets.
# see also: http://stackoverflow.com/questions/1883925/kernelgets-attempts-to-read-file-instead-of-standard-input
ARGV.clear

Flare::Tools::Cli::Dispatch.new.main(cliname, argv, false)
