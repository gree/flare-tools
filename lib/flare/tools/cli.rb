# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

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
    end
  end
end


