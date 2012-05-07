# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

# 
module Flare
  module Tools
    module Cli
      autoload :List,        'flare/tools/cli/list'
      autoload :Stats,       'flare/tools/cli/stats'
      autoload :Index,       'flare/tools/cli/index'
      autoload :Balance,     'flare/tools/cli/balance'
      autoload :Down,        'flare/tools/cli/down'
      autoload :Slave,       'flare/tools/cli/slave'
      autoload :Reconstruct, 'flare/tools/cli/reconstruct'
      autoload :Master,      'flare/tools/cli/master'
      autoload :Deploy,      'flare/tools/cli/deploy'
      autoload :Threads,     'flare/tools/cli/threads'
      autoload :Ping,        'flare/tools/cli/ping'
      autoload :Remove,      'flare/tools/cli/remove'
      autoload :Activate,    'flare/tools/cli/activate'
      autoload :Dump,        'flare/tools/cli/dump'
      autoload :Dumpkey,     'flare/tools/cli/dumpkey'
      autoload :Verify,      'flare/tools/cli/verify'
      autoload :Restore,     'flare/tools/cli/restore'
    end
  end
end


