# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

# 
module Flare
  module Util
    
    module Exception
      class ServerError < StandardError
        def message
          "ServerError: "+super
        end
      end
    end
  end
end

