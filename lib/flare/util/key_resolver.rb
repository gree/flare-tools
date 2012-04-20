
module Flare
  module Util
    class KeyResolver
      class Modular
        def initialize params
          @partition_size = params[:partition_size] || 1024
          @virtual = params[:virtual] || 4096
          @hint = params[:hint] || 1
          @map = Array.new(@partition_size+1).map!{Array.new(@virtual, -1)}
          @next_calculate = 0
          calculate 1
        end

        def calculate psize
          return if psize < @next_calculate
          (@next_calculate..psize).each do |i|
            if i == 0
              (0...@virtual).each do |j|
                @map[i][j] = 0
              end
            else
              counter = Array.new(psize, 0)
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
          @next_calculate = psize+1
        end

        def resolve key_hash_value, partition_size
          calculate partition_size
          @map[partition_size][key_hash_value % @virtual]
        end

        def map partition_size, virtual
          calculate partition_size
          @map[partition_size][virtual]
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

