# frozen_string_literal: true

module Wildling
  class Token
    def initialize(options)
      options = symbolize_keys(options)
      @src = options.fetch(:src, "")
      @start_length = default_integer(options[:startLength], 1)
      @end_length = default_integer(options[:endLength], 1)
      @variants = options[:variants] || []
      @count = 0
      (@start_length..@end_length).each do |length|
        @count += @variants.length**length
      end
    end

    def count
      @count
    end

    def src
      @src
    end

    def get(index)
      return "" if index > @count - 1 || index < 0
      return "" if index.zero? && @start_length.zero?

      index_with_offset = index
      string_length = @start_length
      (@start_length..@end_length).each do |length|
        string_length = length
        offset_count = @variants.length**length
        break if index_with_offset < offset_count

        index_with_offset -= offset_count
      end

      string_array = []
      string_length.times do
        variant_index = index_with_offset % @variants.length
        index_with_offset /= @variants.length
        string_array << @variants[variant_index]
      end
      string_array.join
    end

    private

    def default_integer(option, fallback)
      option.is_a?(Integer) && option >= 0 ? option : fallback
    end

    def symbolize_keys(hash)
      hash.transform_keys { |key| key.is_a?(String) ? key.to_sym : key }
    end
  end
end
