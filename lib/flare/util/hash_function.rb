
require 'zlib'

module Flare
  module Util
    module HashFunction
      def get_key_hash_value key, type, word_size = 64
        f = {
          :simple => lambda {|k| r = 0; k.each_byte {|c| r += c }; r },
          :bitshift => lambda {|k| r = 19790217; k.each_byte {|c| r = (r << 5) + (r << 2) + r + c }; r },
          :crc32 => lambda {|k| Zlib.crc32(k, 0) },
        }[type]
        return nil if f.nil?
        h = f.call(key)
        key_hash_value = if word_size == 32
                           [h].pack("I").unpack("i")[0]
                         elsif word_size == 64
                           [h].pack("Q").unpack("q")[0]
                         else
                           h
                         end
        key_hash_value = -key_hash_value if key_hash_value < 0
        return key_hash_value
      end
    end
  end
end

