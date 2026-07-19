defmodule Wildling.ParsePattern do
  @moduledoc false

  alias Wildling.Token

  @token_parsing_regex ~r/(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])/

  def parse_pattern(input_pattern, dictionaries \\ %{}) do
    dictionaries = dictionaries || %{}

    Regex.split(@token_parsing_regex, input_pattern, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&part_to_token(&1, dictionaries))
  end

  def parse_length_with_variants(part, variants) do
    {start_length, end_length} =
      case Regex.run(~r/\{((\d+)-(\d+)|(\d+))\}/, part) do
        nil ->
          {1, 1}

        match ->
          start_cap = Enum.at(match, 2)
          end_cap = Enum.at(match, 3)
          group1 = Enum.at(match, 1)

          cond do
            present_digits?(start_cap) and present_digits?(end_cap) ->
              {String.to_integer(start_cap), String.to_integer(end_cap)}

            present_digits?(group1) ->
              n = String.to_integer(group1)
              {n, n}

            true ->
              {1, 1}
          end
      end

    %{
      "variants" => variants,
      "startLength" => start_length,
      "endLength" => end_length,
      "src" => part
    }
  end

  defp present_digits?(value) when is_binary(value), do: Regex.match?(~r/\A\d+\z/, value)
  defp present_digits?(_), do: false

  def parse_length_with_string(part) do
    case Regex.run(~r/\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}/, part) do
      nil ->
        false

      matches ->
        string = Enum.at(matches, 1) || ""
        start_s = Enum.at(matches, 2)
        end_s = Enum.at(matches, 3)
        length_s = Enum.at(matches, 4)

        cond do
          present_digits?(start_s) and present_digits?(end_s) ->
            %{
              "string" => string,
              "startLength" => String.to_integer(start_s),
              "endLength" => String.to_integer(end_s),
              "src" => part
            }

          present_digits?(length_s) ->
            n = String.to_integer(length_s)

            %{
              "string" => string,
              "startLength" => n,
              "endLength" => n,
              "src" => part
            }

          true ->
            %{
              "string" => string,
              "startLength" => 1,
              "endLength" => 1,
              "src" => part
            }
        end
    end
  end

  def simple_tokenizer(variants_string) do
    variants = String.graphemes(variants_string)

    fn part ->
      Token.new(parse_length_with_variants(part, variants))
    end
  end

  def dictionary_tokenizer(part, dictionaries) do
    options = parse_length_with_string(part)

    options =
      if options == false or
           (is_map(options) and options["string"] != "" and options["string"] != nil and
              not Map.has_key?(dictionaries, options["string"])) do
        %{
          "variants" => [part],
          "startLength" => 1,
          "endLength" => 1,
          "src" => part
        }
      else
        string = options["string"] || ""
        Map.put(options, "variants", Map.get(dictionaries, string, []))
      end

    Token.new(options)
  end

  def words_tokenizer(part) do
    options = parse_length_with_string(part)

    options =
      if options == false do
        %{
          "variants" => [part],
          "startLength" => 1,
          "endLength" => 1,
          "src" => part
        }
      else
        variants = split_escaped_commas(options["string"] || "")
        Map.put(options, "variants", variants)
      end

    Token.new(options)
  end

  def part_to_token(part, dictionaries) do
    tokenizers = %{
      "#" => simple_tokenizer("0123456789"),
      "@" => simple_tokenizer("abcdefghijklmnopqrstuvwxyz"),
      "*" => simple_tokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
      "-" =>
        simple_tokenizer(
          "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        ),
      "!" => simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
      "?" => simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
      "&" => simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
      "%" => fn p -> dictionary_tokenizer(p, dictionaries) end,
      "$" => &words_tokenizer/1
    }

    first = if part == "", do: nil, else: String.first(part)
    tokenizer = if first, do: Map.get(tokenizers, first), else: nil

    is_escaped =
      String.length(part) > 1 and String.first(part) == "\\" and
        Map.has_key?(tokenizers, String.at(part, 1))

    cond do
      is_function(tokenizer, 1) ->
        tokenizer.(part)

      is_escaped ->
        Token.new(%{
          "variants" => [String.replace_prefix(part, "\\", "")],
          "src" => part
        })

      true ->
        Token.new(%{
          "variants" => [part],
          "src" => part
        })
    end
  end

  defp split_escaped_commas(work_string) do
    do_split_escaped(work_string, 0, [])
  end

  defp do_split_escaped(work_string, index, variants) do
    cond do
      index >= String.length(work_string) ->
        (variants ++ [work_string])
        |> Enum.map(&String.replace(&1, "\\,", ","))

      String.slice(work_string, index, 2) == "\\," ->
        do_split_escaped(work_string, index + 2, variants)

      String.at(work_string, index) == "," ->
        variant = String.slice(work_string, 0, index)
        rest = String.slice(work_string, index + 1, max(String.length(work_string) - index - 1, 0))
        do_split_escaped(rest, 0, variants ++ [variant])

      true ->
        do_split_escaped(work_string, index + 1, variants)
    end
  end
end
