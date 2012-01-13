# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

require 'optparse'

# Variables
delimiter = "::"
use_prefix = false
use_bucket = false
prefixes = {}
virtual = 4096
size = 0
buckets = {}
bucket_file = nil
default_bucket_file = "bucket.csv"
partition_size = 100
hint = 1

# Options
opt = OptionParser.new
opt.on('-d', '--delimiter=[STRING]',        "delimiter (defalut #{delimiter})") {|v| delimiter = v; use_prefix = true }
opt.on('-b', '--bucket-file=[CSVFILE]',     "bucket file (default #{default_bucket_file})") {|v| bucket_file = v; }
opt.on('-s', '--partition-size=[SIZE]',     "max partition size (default #{partition_size})") {|v| partition_size = v.to_i }
opt.parse!(ARGV)

# Setup
hash = lambda {|k| r = 0; k.each_byte {|c| r += c }; r }

# Bucket
if bucket_file.nil?
  while line = STDIN.gets
    key = line.chomp
    prefix, suffix = split(delimiter, 2)
    unless prefixes.has_key? prefix
      prefixes[prefix] = 0
      buckets[prefix] = Array.new(virtual, 0)
    end
    prefixes[prefix] += 1
    buckets[prefix][hash.call(key)%virtual] += 1
    size += 1
  end
  bucket_file = default_bucket_file
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
(0..partition_size).each do |i|
  next if i == 0
  counter = Array.new(partition_size, 0)
  (0...virtual).each do |j|
    if i <= hint
      map[i][j] = j % i
      next
    end
    k = map[i-1][j]
    counter[k] += 1
    map[i][j] = if (counter[k] % i) == (i - 1) then i - 1 else map[i-1][j] end
  end
end

puts "partition size, prefix, "+(0...partition_size).map{|x| x.to_s}.join(' ,')
for i in 1..partition_size
  prefixes.each do |prefix, total|
    nitem = Array.new(i, 0)
    for j in (0...virtual)
      rn = map[i][j]
      nitem[rn] += buckets[prefix][j]
    end
    puts "#{i},#{prefix},"+nitem.join(' ,')
  end
end
