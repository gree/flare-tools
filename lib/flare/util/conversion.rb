# -*- coding: utf-8; -*-

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    # 
    # == Description
    # 
    module Conversion
      def short_desc_of_second(second)
        second, unit = second.to_i, "s"
        second, unit = second / 60, "m" if second >= 60
        second, unit = second / 60, "h" if second >= 60
        second, unit = second / 24, "d" if second >= 24
        "#{second}#{unit}"
      end
    end
  end
end

