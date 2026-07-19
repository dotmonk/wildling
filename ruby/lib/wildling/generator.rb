# frozen_string_literal: true

require_relative "parse_pattern"

module Wildling
  class Generator
    attr_reader :source

    def initialize(input_pattern, dictionaries)
      @source = input_pattern
      @tokens = ::Wildling.parse_pattern(input_pattern, dictionaries)
      @count = 1
      @tokens.each { |token| @count *= token.count }
    end

    def count
      @count
    end

    def tokens
      @tokens
    end

    def get(index)
      return "" if index > @count - 1 || index < 0

      string_array = []
      index_with_offset = index
      @tokens.each do |token|
        string_array << token.get(index_with_offset % token.count)
        index_with_offset /= token.count
      end
      string_array.join
    end
  end
end
