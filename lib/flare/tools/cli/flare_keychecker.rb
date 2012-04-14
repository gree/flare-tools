# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'optparse'
require "zlib"

# Hash
hashfunc = {
  "simple" => lambda {|k| r = 0; k.each_byte {|c| r += c }; r },
  "bitshift" => lambda {|k| r = 19790217; k.each_byte {|c| r = (r << 5) + (r << 2) + r + c }; r },
  "crc32" => lambda {|k| Zlib.crc32(k, 0) },
}

# Variables
delimiter = "::"
use_prefix = false
use_bucket = false
prefixes = {}
virtual = 4096
size = 0
buckets = {}
bucket_file = nil
partition_size = 100
hint = 1
hash = hashfunc["simple"]
output_file = nil
input_file = nil
default_bucket_file = "bucket.csv"

# Options
opt = OptionParser.new
opt.on('-d', '--delimiter=[STRING]',        "delimiter (defalut #{delimiter})") {|v| delimiter = v; use_prefix = true }
opt.on('-b', '--bucket-file=[CSVFILE]',     "bucket file (default #{default_bucket_file})") {|v| bucket_file = v; }
opt.on('-i', '--input=[CSVFILE]',           "input file") {|v| input_file = v; }
opt.on('-o', '--output=[CSVFILE]',          "output file") {|v| output_file = v; }
opt.on('-s', '--partition-size=[SIZE]',     "max partition size (default #{partition_size})") {|v| partition_size = v.to_i }
opt.on('-h', '--hash=[TYPE]',               "hash function (simple,bitshift,crc32)") {|v|
  default_bucket_file = "bucket.#{v}.csv"
  hash = if hashfunc.has_key? v then hashfunc[v] else abort "invalid hash function." end
}
opt.on('-n', '--hint=[SIZE]',               "hint (default #{hint})") {|v| hint = v; }
opt.parse!(ARGV)

# Bucket
if bucket_file.nil? || (!input_file.nil? && File.exist?(input_file))
  bucket_file = default_bucket_file
  input = if input_file.nil? then STDIN else open(input_file) end
  while line = input.gets
    key = line.chomp
    parts = split(delimiter)
    suffix = parts.pop
    prefix = parts.join(delimiter)
    unless prefixes.has_key? prefix
      prefixes[prefix] = 0
      buckets[prefix] = Array.new(virtual, 0)
    end
    prefixes[prefix] += 1
    key_hash_value = [hash.call(key)].pack("l").unpack("L")[0]
    key_hash_value = -key_hash_value if key_hash_value < 0
    buckets[prefix][key_hash_value%virtual] += 1
    size += 1
  end
  if File.exist? bucket_file
    print "#{bucket_file} exists. overwrite? (y/n): "
    exit unless gets.chomp.upcase == "Y"
  end
  open(bucket_file, 'w') do |f|
    f.puts "# key, total, ..."
    prefixes.each do |k,total|
      f.puts k+", "+total.to_s+", "+buckets[k].join(" ,")
    end
  end
else
  open(bucket_file) do |f|
    while line = f.gets
      prefix, total, data = line.split(',', 3)
      prefixes[prefix] = total.to_i
      buckets[prefix] = data.split(',').map {|x| x.to_i}
    end
  end
end

# Assign
map = Array.new(partition_size+1).map!{Array.new(virtual, 0)}
(1..partition_size).each do |i|
  counter = Array.new(partition_size, 0)
  (0..hint).each {|j| map[i][j] = j % i }
  ((hint+1)...virtual).each do |j|
    k = map[i-1][j]
    counter[k] += 1
    map[i][j] = if (counter[k] % i) == (i - 1) then i - 1 else map[i-1][j] end
  end
end

# Result
output = if output_file.nil? || !File.exist?(output_file) then STDOUT else open(output_file, "w") end
output.puts "partition size, prefix, "+(0...partition_size).map{|x| "#{x}"}.join(' ,')
for i in 1..partition_size
  prefixes.each do |prefix, total|
    nitem = Array.new(i, 0)
    (0...virtual).each {|j| nitem[map[i][j]] += buckets[prefix][j] }
    output.puts "#{i}, #{prefix},"+nitem.join(' ,')
  end
end
