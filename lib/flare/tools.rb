# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

# 
module Flare

  # flare-tools module.
  module Tools
    # the version number of flare-tools
    VERSION = '0.3.0'
    TITLE = "Flare-tools version #{VERSION} Copyright (C) GREE, Inc. 2011-2012"
    autoload :Common,      'flare/tools/common'
    autoload :Cluster,     'flare/tools/cluster'
    autoload :Stats,       'flare/tools/stats'
    autoload :Node,        'flare/tools/node'
    autoload :IndexServer, 'flare/tools/index_server'
    autoload :Cli,         'flare/tools/cli'
  end
end
