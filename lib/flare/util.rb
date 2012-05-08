# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>
# Copyright:: Copyright (C) GREE, Inc. 2011.
# License::   MIT-style

# 
module Flare

  # == Description
  # Flare::Util module is a moudle that includes utility classes for basic feature of flare-tools and other utilities.
  # This module shouled be moved to a common package, but for now we distribute it with flare-tools.
  # 
  # Constant::   a module which defines common constants widely used by codes related to Flare.
  # Conversion:: a module which covers verious unit conversion functions.
  # Logger::     a logging class.
  # Logging::    a mix-in module for Logger.
  # Result::     a result code handling mix-in module.
  # Conf::       an abstract base class of FlaredConf and FlareiConf.
  # FlareiConf:: a class for flarei.conf.
  # FlaredConf:: a class for flared.conf.
  # FileSystem:: a file system manipulation class.
  # 
  module Util
    autoload :Constant, 'flare/util/constant'
    autoload :Conversion, 'flare/util/conversion'
    autoload :Logging, 'flare/util/logging'
    autoload :Result, 'flare/util/result'
    autoload :Conf, 'flare/util/conf'
    autoload :FlaredConf, 'flare/util/flared_conf'
    autoload :FlareiConf, 'flare/util/flarei_conf'
    autoload :FileSystem, 'flare/util/filesystem'
  end
end
