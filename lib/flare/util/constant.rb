# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

# 
module Flare
  module Util
    
    # == Description
    # 
    module Constant
      # the default index server name
      DefaultIndexServerName = '127.0.0.1'
      # the default port number of flarei daemon
      DefaultIndexServerPort = 12120
      # the default port number of flared
      DefaultNodePort        = 12121
      # the default timeout of client connections (sec.)
      DefaultTimeout         = 10
      # the default bandwidth limit (bps)
      DefalutBwlimit         = 0 # unlimited
    end
  end
end
