# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
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

      def string_of_result(result)
        case result
        when None
          ""
        when Ok,End,Stored,NotStored,Exists,NotFound,Deleted,Found,Error,ClientError,ServerError
          result.to_s
        else
          raise "Invalid argument '"+result.to_s+"'"
        end
      end
      
      def result_of_string(string)
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
