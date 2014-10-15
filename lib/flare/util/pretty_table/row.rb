# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

module Flare
  module Util
    module PrettyTable
      class Row
        attr_reader :columns

        def initialize(option = {})
          @columns = []
          @separator = option[:separator] || ' '
        end

        def add_column(column)
          @columns << column
        end

        def prettify(column_widths)
          @columns \
            .each_with_index.map {|column, index| column.prettify(column_widths[index]) } \
            .join(@separator)
        end
      end
    end
  end
end
