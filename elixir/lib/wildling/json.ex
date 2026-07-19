defmodule Wildling.Json do
  @moduledoc """
  Minimal JSON parser for wildling template files (stdlib only).
  """

  def parse(text) when is_binary(text) do
    {value, rest} = parse_value(skip_ws(text))
    rest = skip_ws(rest)

    if rest != "" do
      raise ArgumentError, "Unexpected trailing JSON content"
    end

    value
  end

  def parse_object(text) do
    value = parse(text)

    if is_map(value) do
      value
    else
      raise ArgumentError, "Template root must be a JSON object"
    end
  end

  defp skip_ws(<<c::utf8, rest::binary>>) when c in [?\s, ?\n, ?\r, ?\t], do: skip_ws(rest)
  defp skip_ws(text), do: text

  defp parse_value(<<"{"::binary, _::binary>> = text), do: parse_object_value(text)
  defp parse_value(<<"["::binary, _::binary>> = text), do: parse_array(text)
  defp parse_value(<<"\""::binary, _::binary>> = text), do: parse_string(text)
  defp parse_value(<<"true", rest::binary>>), do: {true, rest}
  defp parse_value(<<"false", rest::binary>>), do: {false, rest}
  defp parse_value(<<"null", rest::binary>>), do: {nil, rest}

  defp parse_value(<<c::utf8, _::binary>> = text) when c == ?- or (c >= ?0 and c <= ?9) do
    parse_number(text)
  end

  defp parse_value(""), do: raise(ArgumentError, "Unexpected end of JSON")
  defp parse_value(_), do: raise(ArgumentError, "Unexpected character in JSON")

  defp parse_string(<<"\"", rest::binary>>), do: do_parse_string(rest, [])

  defp do_parse_string(<<"\"", rest::binary>>, acc) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
  end

  defp do_parse_string(<<"\\", esc::utf8, rest::binary>>, acc) do
    case esc do
      ?" -> do_parse_string(rest, [?" | acc])
      ?\\ -> do_parse_string(rest, [?\\ | acc])
      ?/ -> do_parse_string(rest, [?/ | acc])
      ?b -> do_parse_string(rest, [?\b | acc])
      ?f -> do_parse_string(rest, [?\f | acc])
      ?n -> do_parse_string(rest, [?\n | acc])
      ?r -> do_parse_string(rest, [?\r | acc])
      ?t -> do_parse_string(rest, [?\t | acc])
      ?u ->
        case rest do
          <<a, b, c, d, more::binary>> ->
            hex = <<a, b, c, d>>

            if Regex.match?(~r/\A[0-9a-fA-F]{4}\z/, hex) do
              code = String.to_integer(hex, 16)
              do_parse_string(more, [<<code::utf8>> | acc])
            else
              raise ArgumentError, "Invalid unicode escape"
            end

          _ ->
            raise ArgumentError, "Invalid unicode escape"
        end

      _ ->
        raise ArgumentError, "Invalid escape"
    end
  end

  defp do_parse_string(<<c::utf8, rest::binary>>, acc) do
    do_parse_string(rest, [<<c::utf8>> | acc])
  end

  defp do_parse_string("", _), do: raise(ArgumentError, "Unterminated string")

  defp parse_number(text) do
    {raw, rest, is_float} = take_number(text, [], false)

    value =
      if is_float do
        case Float.parse(raw) do
          {f, ""} -> f
          _ -> raise ArgumentError, "Invalid number"
        end
      else
        String.to_integer(raw)
      end

    {value, rest}
  end

  defp take_number(<<"-", rest::binary>>, acc, is_float) do
    take_number(rest, ["-" | acc], is_float)
  end

  defp take_number(<<c::utf8, rest::binary>>, acc, is_float) when c >= ?0 and c <= ?9 do
    take_number(rest, [<<c::utf8>> | acc], is_float)
  end

  defp take_number(<<".", rest::binary>>, acc, _) do
    take_number_frac(rest, ["." | acc], true)
  end

  defp take_number(<<c::utf8, rest::binary>>, acc, _is_float) when c in [?e, ?E] do
    take_number_exp(rest, [<<c::utf8>> | acc], true)
  end

  defp take_number(rest, acc, is_float) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest, is_float}
  end

  defp take_number_frac(<<c::utf8, rest::binary>>, acc, _) when c >= ?0 and c <= ?9 do
    take_number_frac(rest, [<<c::utf8>> | acc], true)
  end

  defp take_number_frac(<<c::utf8, rest::binary>>, acc, _) when c in [?e, ?E] do
    take_number_exp(rest, [<<c::utf8>> | acc], true)
  end

  defp take_number_frac(rest, acc, is_float) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest, is_float}
  end

  defp take_number_exp(<<"+", rest::binary>>, acc, _) do
    take_number_exp_digits(rest, ["+" | acc], true)
  end

  defp take_number_exp(<<"-", rest::binary>>, acc, _) do
    take_number_exp_digits(rest, ["-" | acc], true)
  end

  defp take_number_exp(rest, acc, is_float) do
    take_number_exp_digits(rest, acc, is_float)
  end

  defp take_number_exp_digits(<<c::utf8, rest::binary>>, acc, _) when c >= ?0 and c <= ?9 do
    take_number_exp_digits(rest, [<<c::utf8>> | acc], true)
  end

  defp take_number_exp_digits(rest, acc, is_float) do
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest, is_float}
  end

  defp parse_array(<<"[", rest::binary>>) do
    rest = skip_ws(rest)

    if match?(<<"]", _::binary>>, rest) do
      <<"]", more::binary>> = rest
      {[], more}
    else
      parse_array_items(rest, [])
    end
  end

  defp parse_array_items(text, acc) do
    {value, rest} = parse_value(skip_ws(text))
    rest = skip_ws(rest)

    case rest do
      <<"]", more::binary>> ->
        {Enum.reverse([value | acc]), more}

      <<",", more::binary>> ->
        parse_array_items(more, [value | acc])

      _ ->
        raise ArgumentError, "Expected ',' or ']' in JSON array"
    end
  end

  defp parse_object_value(<<"{", rest::binary>>) do
    rest = skip_ws(rest)

    if match?(<<"}", _::binary>>, rest) do
      <<"}", more::binary>> = rest
      {%{}, more}
    else
      parse_object_pairs(rest, [])
    end
  end

  defp parse_object_pairs(text, acc) do
    {key, rest} = parse_string(skip_ws(text))
    rest = skip_ws(rest)

    case rest do
      <<":", more::binary>> ->
        {value, rest} = parse_value(skip_ws(more))
        rest = skip_ws(rest)
        acc = [{key, value} | acc]

        case rest do
          <<"}", more::binary>> ->
            {Map.new(Enum.reverse(acc)), more}

          <<",", more::binary>> ->
            parse_object_pairs(more, acc)

          _ ->
            raise ArgumentError, "Expected ',' or '}' in JSON object"
        end

      _ ->
        raise ArgumentError, "Expected ':' in JSON object"
    end
  end
end
