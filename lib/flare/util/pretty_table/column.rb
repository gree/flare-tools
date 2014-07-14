# -*- coding: utf-8; -*-
# Authors::   Yuya YAGUCHI <yuya.yaguchi@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2014.
# License::   MIT-style

module Flare
  module Util
    module PrettyTable
      class Column
        def initialize(text, options = {})
          @text = text.to_s
          @align = options[:align] || :left
        end

        def width
          @text.size
        end

        def prettify(column_width)
          if self.width >= column_width
            return @text
          end

          padding = padding(column_width - self.width)
          case @align
          when :left then
            @text + padding
          else # @align == :right
            padding + @text
          end
        end

        private

        def padding(length)
          ' ' * length
        end
      end
    end
  end
end
