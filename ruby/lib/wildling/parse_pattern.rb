# frozen_string_literal: true

require_relative "token"

module Wildling
  TOKEN_PARSING_REGEX = /(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])/

  module_function

  def parse_length_with_variants(part, variants)
    match = part.match(/\{((\d+)-(\d+)|(\d+))\}/)

    start_length = 1
    end_length = 1

    if match
      if match[2]
        start_length = match[2].to_i
        end_length = match[3].to_i
      elsif match[1]
        start_length = match[1].to_i
        end_length = start_length
      end
    end

    {
      "variants" => variants,
      "startLength" => start_length,
      "endLength" => end_length,
      "src" => part
    }
  end

  def parse_length_with_string(part)
    match = part.match(/\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}/)
    return false unless match

    if match[2] && match[3]
      return {
        "string" => match[1] || "",
        "startLength" => match[2].to_i,
        "endLength" => match[3].to_i,
        "src" => part
      }
    end

    if match[4]
      length = match[4].to_i
      return {
        "string" => match[1] || "",
        "startLength" => length,
        "endLength" => length,
        "src" => part
      }
    end

    {
      "string" => match[1] || "",
      "startLength" => 1,
      "endLength" => 1,
      "src" => part
    }
  end

  def simple_tokenizer(variants_string)
    variants = variants_string.chars
    lambda do |part|
      Token.new(parse_length_with_variants(part, variants))
    end
  end

  def dictionary_tokenizer(part, dictionaries)
    options = parse_length_with_string(part)
    if options == false || (options["string"] && !options["string"].empty? && !dictionaries.key?(options["string"]))
      options = {
        "variants" => [part],
        "startLength" => 1,
        "endLength" => 1,
        "src" => part
      }
    else
      options["variants"] = dictionaries[options["string"] || ""] || []
    end
    Token.new(options)
  end

  def words_tokenizer(part)
    options = parse_length_with_string(part)

    if options == false
      options = {
        "variants" => [part],
        "startLength" => 1,
        "endLength" => 1,
        "src" => part
      }
    else
      variants = []
      work_string = options["string"] || ""
      index = 0
      while index < work_string.length
        if work_string[index, 2] == "\\,"
          index += 2
        elsif work_string[index] == ","
          variants << work_string[0...index]
          work_string = work_string[(index + 1)..] || ""
          index = 0
        else
          index += 1
        end
      end
      variants << work_string
      options["variants"] = variants.map { |variant| variant.gsub("\\,", ",") }
    end

    Token.new(options)
  end

  def part_to_token(part, dictionaries)
    tokenizers = {
      "#" => simple_tokenizer("0123456789"),
      "@" => simple_tokenizer("abcdefghijklmnopqrstuvwxyz"),
      "*" => simple_tokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
      "-" => simple_tokenizer(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      ),
      "!" => simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
      "?" => simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
      "&" => simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
      "%" => ->(p) { dictionary_tokenizer(p, dictionaries) },
      "$" => method(:words_tokenizer)
    }

    tokenizer = part.empty? ? nil : tokenizers[part[0]]
    is_escaped = part.length > 1 && part[0] == "\\" && tokenizers.key?(part[1])

    if tokenizer
      tokenizer.call(part)
    elsif is_escaped
      Token.new(
        "variants" => [part.sub(/^\\/, "")],
        "src" => part
      )
    else
      Token.new(
        "variants" => [part],
        "src" => part
      )
    end
  end

  def parse_pattern(input_pattern, dictionaries)
    dictionaries ||= {}
    parts = input_pattern.split(TOKEN_PARSING_REGEX).reject(&:empty?)
    parts.map { |part| part_to_token(part, dictionaries) }
  end
end
