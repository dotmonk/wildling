# frozen_string_literal: true

require_relative "generator"

module Wildling
  VERSION = "2.0.2"

  # Main enumerator. Prefer Wildling.create(...) from callers.
  class Client
    def initialize(patterns, dictionaries = nil)
      @dictionaries = dictionaries || {}
      @generators = patterns.map { |pattern| Generator.new(pattern, @dictionaries) }
      @pattern_count = @generators.sum(&:count)
      @internal_index = 0
    end

    def index
      @internal_index
    end

    def count
      @pattern_count
    end

    def reset
      @internal_index = 0
    end

    def next
      return false if @internal_index == @pattern_count

      @internal_index += 1
      get(@internal_index - 1)
    end

    def generators
      @generators
    end

    def get(index)
      return false if index > @pattern_count - 1 || index < 0

      segment_index = 0
      @generators.each do |generator|
        pattern_index = index - segment_index
        return generator.get(pattern_index) if pattern_index < generator.count

        segment_index += generator.count
      end
      false
    end
  end

  def self.create(patterns, dictionaries = nil)
    Client.new(patterns, dictionaries)
  end
end
