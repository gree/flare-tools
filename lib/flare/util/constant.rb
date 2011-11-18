# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

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
    end
  end
end
