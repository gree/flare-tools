# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

# 
module Flare
  module Util

    # == Description
    # Result is a class for handling result code.
    module Result
      None = nil
      Ok = :OK
      End = :END
      Stored = :STORED
      NotStored = :NOT_STORED
      Exists = :EXISTS
      NotFound= :NOT_FOUND
      Deleted = :DELETED
      Found = :FOUND
      Error = :ERROR
      ClientError = :CLIENT_ERROR
      ServerError = :SERVER_ERROR

      # Converts a result code to its string representation.
      def self.string_of_result(result)
        case result
        when None
          ""
        when Ok,End,Stored,NotStored,Exists,NotFound,Deleted,Found,Error,ClientError,ServerError
          result.to_s
        else
          raise "Invalid argument '"+result.to_s+"'"
        end
      end
      
      # Converts a string representation of a request result to its result code.
      def self.result_of_string(string)
        case string
        when ""
          None
        else
          [Ok,End,Stored,NotStored,Exists,NotFound,Deleted,Found,Error,ClientError,ServerError].each do |x|
            return x if x.to_s == string
          end
          raise "Invalid arugument '"+string.to_s+"'"
        end
      end

    end
  end
end
