# -*- coding: utf-8; -*-

module Flare
  module Util

    # Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
    # Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
    # License::   NOTYET
    #
    # == Description
    # Conf class is the abstract base class of Flare's configuration file classes.
    # You can write sub classes derived from this class as follows.
    #
    #  class FlaredConf < Flare::Util::Conf
    #    DefaultConf = {
    #      'server-name' => "localhost",
    #      'server-port' => "12121",
    #    }
    #    
    #    def initialize(config)
    #      @config = DefaultConf.merge(config)
    #    end
    #  end
    #
    class Conf

      # Initialize a Conf object with a hash object.
      def initialize(config)
        @config = {}
        @config = config unless config.nil?
      end

      # Convert to String object in a configuration file format.
      def to_s
        conf = ""
        @config.each do |k,v|
          conf += "#{k} = #{v}\n"
        end
        conf
      end

      # Iterate item and value pairs.
      def each(&block)
        @config.each do |k,v|
          block.call(k, v) if block
        end
      end

      # Returns "server-name" entry.
      def server_name
        @config['server-name']
      end

      # Returns "server-port" entry.
      def server_port
        @config['server-port']
      end

      # Returns node name in hostname:port style.
      def hostname_port
        "#{server_name}:#{server_port}"
      end

      # Returns "data-dir" entry.
      def data_dir
        @config['data-dir']
      end
      
    end
  end
end
