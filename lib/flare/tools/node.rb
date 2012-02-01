# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'flare/tools/stats'

# 
module Flare
  module Tools

    # == Description
    # 
    class Node < Stats
      
      # (host, port, state)
      defcmd :set_state, 'node state %s %s %s\r\n' do |resp| resp end

      defcmd :flush_all, 'flush_all\r\n' do |resp| resp end

      def x_list_push(k, v)
        x_list_push_(k.chomp, 0, 0, v.size, v)
      end
      defcmd :x_list_push_, 'list_push %s %d %d %d\r\n%s\r\n' do |resp| resp end

      def x_list_unshift(k, v)
        x_list_unshift_(k.chomp, 0, 0, v.size, v)
      end
      defcmd :x_list_unshift_, 'list_unshift %s %d %d %d\r\n%s\r\n' do |resp| resp end

      def set(k, v)
        set_(k.chomp, 0, 0, v.size, v)
      end
      defcmd :set_, 'set %s %d %d %d\r\n%s\r\n' do |resp| resp end

      def set_noreply(k, v)
        set_noreply_(k.chomp, 0, 0, v.size, v)
      end
      defcmd_noreply :set_noreply_, 'set %s %d %d %d noreply\r\n%s\r\n'

      def cas(k, v, casunique)
        r = cas_(k.chomp, 0, 0, v.size, casunique, v)
        r = true if r == ""
        r
      end
      defcmd :cas_, 'cas %s %d %d %d %d\r\n%s\r\n' do |resp| resp end

      def delete(k)
        delete_(k.chomp)
      end
      defcmd :delete_, 'delete %s\r\n' do |resp| resp end

      def delete_noreply(k)
        delete_noreply_(k.chomp)
      end
      defcmd_noreply :delete_noreply_, 'delete %s noreply\r\n'

      def x_list_pop(k)
        r = nil
        x_list_pop_(k.chomp) do |data, key, flag, len, version, expire|
          r = data
        end
        r
      end
      defcmd_value :x_list_pop_, 'list_pop %s\r\n'

      def x_list_shift(k)
        r = nil
        x_list_shift_(k.chomp) do |data, key, flag, len, version, expire|
          r = data
        end
        r
      end
      defcmd_value :x_list_shift_, 'list_shift %s\r\n'

      def x_list_get(k, b, e, &block)
        x_list_get_(k.chomp, b, e, &block)
      end
      defcmd_listelement :x_list_get_, 'list_get %s %d %d\r\n' do |data, key, rel, abs, flag, len, version, expire|
        data
      end

      def get(*keys, &block)
        r = get_(keys.map{|x|x.chomp}.join(' '), &block)
        return false if r == []
        return r[0] if r.size == 1
        r
      end
      defcmd_value :get_, 'get %s\r\n' do |data, key, flag, len, version, expire|
        data
      end

      def gets(*keys, &block)
        r = gets_(keys.map{|x|x.chomp}.join(' '), &block)
        return false if r == []
        return r[0] if r.size == 1
        r
      end
      defcmd_value :gets_, 'gets %s\r\n' do |data, key, flag, len, version, expire|
        [data, version]
      end

      def dump(wait = 0, part = 0, partsize = 1, bwlimit = 0, &block)
        dump_(wait, part, partsize, bwlimit, &block)
      end
      defcmd_value :dump_, 'dump %d %d %d %d\r\n' do |data, key, flag, len, version, expire|
        false
      end

      def dumpkey(part = nil, partsize = nil, &block)
        return dumpkey_0_(&block) if part.nil?
        return dumpkey_1_(part, &block) if partsize.nil?
        return dumpkey_2_(part, partsize, &block)
      end
      defcmd_key :dumpkey_0_, 'dump_key\r\n' do |key|
        false
      end
      defcmd_key :dumpkey_1_, 'dump_key %d\r\n' do |key|
        false
      end
      defcmd_key :dumpkey_2_, 'dump_key %d %d\r\n' do |key|
        false
      end

      def incr_noreply(k, v)
        incr_noreply(k.chomp, v.to_s)
      end
      defcmd_noreply :incr_noreply, 'incr %s %s noreply\r\n'

      def incr(k, v)
        incr_(k.chomp, v.to_s)
      end
      defcmd_oneline :incr_, 'incr %s %s\r\n' do |resp|
        resp.chomp
      end

      def decr_noreply(k, v)
        decr_noreply_(k.chomp, v.to_s)
      end
      defcmd_noreply :decr_noreply_, 'decr %s %s noreply\r\n'

      def decr(k, v)
        decr_(k.chomp, v.to_s)
      end
      defcmd_oneline :decr_, 'decr %s %s\r\n' do |resp|
        resp.chomp
      end

    end
  end
end
