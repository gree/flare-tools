# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) Gree, Inc. 2011.
# License::   MIT-style

# 
module Flare
  module Util

    # == Description
    # 
    module FileSystem
      
      # Delete all the contents in a directory.
      def delete_all(file_or_directory)
        return unless FileTest.exist?(file_or_directory)
        if FileTest.directory?(file_or_directory)
          Dir.foreach(file_or_directory) do |file|
            next if /^\.+$/ =~ file
            delete_all(file_or_directory.sub(/\/+$/,"") + "/" + file)
          end
          Dir.rmdir(file_or_directory) rescue ""
        else
          File.delete(file_or_directory)
        end
      end

    end
  end
end
