# frozen_string_literal: true

require "json"
require_relative "wildling"

module Wildling
  module Cli
    module_function

    CliArgs = Struct.new(
      :selects, :ranges, :check, :dictionaries, :patterns, :help, :version,
      keyword_init: true
    )

    def parse_range(value)
      parts = value.split("-", 2)
      return nil if parts.length != 2 || !parts[0].match?(/\A\d+\z/) || !parts[1].match?(/\A\d+\z/)

      start = parts[0].to_i
      finish = parts[1].to_i
      start <= finish ? [start, finish] : nil
    end

    def load_dictionary_file(path)
      File.read(path, encoding: "UTF-8").split(/\r?\n/).map(&:strip).reject(&:empty?)
    end

    def apply_dictionary(result, name, value)
      if value.is_a?(Array)
        result.dictionaries[name] = value.map(&:to_s)
        return
      end
      return unless value.is_a?(String) && File.exist?(value)

      begin
        result.dictionaries[name] = load_dictionary_file(value)
      rescue SystemCallError
        # ignore unreadable dictionary files
      end
    end

    def apply_template(result, path)
      unless File.exist?(path)
        warn "Template file not found: #{path}"
        exit 1
      end

      begin
        template = JSON.parse(File.read(path, encoding: "UTF-8"))
      rescue SystemCallError, JSON::ParserError
        warn "Invalid JSON template: #{path}"
        exit 1
      end

      unless template.is_a?(Hash)
        warn "Invalid JSON template: #{path}"
        exit 1
      end

      result.check = true if template["check"] == true

      select = template["select"]
      if select.is_a?(Array)
        select.each do |val|
          number = Integer(val)
          result.selects << number if number >= 0
        rescue ArgumentError, TypeError
          next
        end
      end

      ranges = template["range"]
      if ranges.is_a?(Array)
        ranges.each do |range_str|
          parsed = parse_range(range_str.to_s)
          result.ranges << parsed if parsed
        end
      end

      dictionaries = template["dictionaries"]
      if dictionaries.is_a?(Hash)
        dictionaries.each do |name, value|
          apply_dictionary(result, name.to_s, value) if value.is_a?(String) || value.is_a?(Array)
        end
      end

      patterns = template["patterns"]
      if patterns.is_a?(Array)
        patterns.each { |pattern| result.patterns << pattern.to_s }
      end
    end

    def parse_args(args)
      result = CliArgs.new(
        selects: [],
        ranges: [],
        check: false,
        dictionaries: {},
        patterns: [],
        help: false,
        version: false
      )
      i = 0
      while i < args.length
        arg = args[i]

        case arg
        when "--help", "-h"
          result.help = true
          i += 1
        when "--version", "-v"
          result.version = true
          i += 1
        when "--check"
          result.check = true
          i += 1
        when "--select"
          i += 1
          break if i >= args.length

          begin
            val = Integer(args[i])
            result.selects << val if val >= 0
          rescue ArgumentError, TypeError
            # skip invalid select
          end
          i += 1
        when "--range"
          i += 1
          break if i >= args.length

          parsed = parse_range(args[i])
          result.ranges << parsed if parsed
          i += 1
        when "--dictionary"
          i += 1
          break if i >= args.length

          name, path = args[i].split(":", 2)
          apply_dictionary(result, name, path) if name && path && !name.empty? && !path.empty?
          i += 1
        when "--template"
          i += 1
          if i >= args.length
            warn "Missing path for --template"
            exit 1
          end
          apply_template(result, args[i])
          i += 1
        else
          result.patterns << arg
          i += 1
        end
      end
      result
    end

    def load_help_text
      here = File.expand_path(__dir__)
      candidates = [
        File.join(here, "help.txt"),
        File.join(here, "..", "..", "docs", "help.txt")
      ]
      candidates.each do |path|
        return File.read(path, encoding: "UTF-8") if File.exist?(path)
      end
      "wildling - pattern based string generator\n\nHelp text unavailable.\n"
    end

    def format_list(values)
      values.nil? || values.empty? ? "" : " #{values.map(&:to_s).join(' ')}"
    end

    def format_check_output(args, total, generators)
      lines = [
        "patterns:#{format_list(args.patterns)}",
        "dictionaries:#{format_list(args.dictionaries.keys)}",
        "select:#{format_list(args.selects)}",
        "range:#{format_list(args.ranges.map { |start, finish| "#{start}-#{finish}" })}",
        "total: #{total}"
      ]
      generators.each do |gen|
        lines << "generator: #{gen.source} #{gen.count}"
      end
      lines.join("\n")
    end

    def main(argv = nil)
      args = parse_args(argv || ARGV)

      if args.help
        puts load_help_text.rstrip
        exit 0
      end

      if args.version
        puts "wildling #{VERSION}"
        exit 0
      end

      if args.patterns.empty?
        warn "No pattern provided. Use --help for usage information."
        exit 1
      end

      wildcard = ::Wildling.create(args.patterns, args.dictionaries)

      if args.check
        puts format_check_output(args, wildcard.count, wildcard.generators)
        exit 0
      end

      if !args.selects.empty? || !args.ranges.empty?
        oor = false
        args.selects.each do |index|
          value = wildcard.get(index)
          if value == false
            $stderr.puts "out of range: #{index}"
            oor = true
          else
            puts value
          end
        end
        args.ranges.each do |start, finish|
          (start..finish).each do |index|
            value = wildcard.get(index)
            if value == false
              $stderr.puts "out of range: #{index}"
              oor = true
            else
              puts value
            end
          end
        end
        exit(oor ? 1 : 0)
      end

      value = wildcard.next
      while value != false
        puts value
        value = wildcard.next
      end
    end
  end
end
