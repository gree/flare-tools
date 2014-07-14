# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

module Flare
  module Util
    module PrettyTable
      class Table
        def initialize
          @rows = []
        end

        def add_row(row)
          @rows << row
        end

        def prettify
          column_widths = max_column_widths
          @rows \
            .map {|row| row.prettify(column_widths) } \
            .join("\n")
        end

        def max_column_widths
          widths = []
          @rows.each do |row|
            row.columns.each_with_index do |column, index|
              widths[index] = [column.width, (widths[index] || 0)].max
            end
          end
          widths
        end
      end
    end
  end
end
