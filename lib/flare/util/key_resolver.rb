
module Flare
  module Util
    class KeyResolver
      class Modular
        def initialize params
          @partition_size = params[:partition_size] || 1024
          @virtual = params[:virtual] || 4096
          @hint = params[:hint] || 1

          @map = Array.new(@partition_size).map!{Array.new(@virtual, 0)}

          (0...@partition_size).each do |i|
            next if i == 0
            counter = Array.new(@partition_size, 0)

            (0...@virtual).each do |j|
              if i <= @hint
                @map[i][j] = j % i
                next
              end
              k = @map[i-1][j]
              counter[k] += 1
              if (counter[k] % i) == (i - 1)
                @map[i][j] = i - 1
              else
                @map[i][j] = @map[i-1][j]
              end
            end
          end
        end
        def resolve key_hash_value, partition_size
          @map[partition_size][key_hash_value % @virtual]
        end
      end

      def initialize(type = :modular, options = {})
        @resolver = Modular.new options
      end

      def resolve key_hash_value, partition_size
        @resolver.resolve key_hash_value, partition_size
      end
    end
  end
end

