# -*- coding: utf-8; -*-

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    module Exception
      class ServerError < StandardError
        def message
          "ServerError: "+super
        end
      end
    end
  end
end

