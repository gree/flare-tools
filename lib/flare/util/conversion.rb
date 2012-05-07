# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

# 
module Flare
  module Util

    # 
    # == Description
    # 
    module Conversion
      def short_desc_of_second(second)
        second, unit = second.to_i, "s"
        minute, second, unit = (second/60), (second%60), "m" if second >= 60
        hour, minute, unit = (minute/60), (minute%60), "h" if minute && minute >= 60
        day, hour, unit = (hour/24), (hour%24), "d" if hour && hour >= 24
        n = (day || minute || hour || second)
        "#{n}#{unit}"
      end
    end
  end
end

