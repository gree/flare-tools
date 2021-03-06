# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011-2014.
# License::   MIT-style

# 
module Flare

  # flare-tools module.
  module Tools
    # the version number of flare-tools
    VERSION = '0.7.3'
    TITLE = "Flare-tools version #{VERSION} Copyright (C) GREE, Inc. 2011-2017"
    autoload :Common,      'flare/tools/common'
    autoload :Cluster,     'flare/tools/cluster'
    autoload :Stats,       'flare/tools/stats'
    autoload :Node,        'flare/tools/node'
    autoload :IndexServer, 'flare/tools/index_server'
    autoload :Cli,         'flare/tools/cli'
    autoload :ZkUtil,      'flare/tools/zk_util'
  end
end
