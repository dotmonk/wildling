defmodule Wildling.Token do
  @moduledoc false

  defstruct src: "", start_length: 1, end_length: 1, variants: [], count: 0

  def new(options) when is_map(options) do
    src = Map.get(options, "src", Map.get(options, :src, ""))
    start_length = default_integer(Map.get(options, "startLength", Map.get(options, :startLength)), 1)
    end_length = default_integer(Map.get(options, "endLength", Map.get(options, :endLength)), 1)
    variants = Map.get(options, "variants", Map.get(options, :variants, [])) || []

    variant_count = length(variants)

    count =
      Enum.reduce(start_length..end_length, 0, fn len, acc ->
        acc + int_pow(variant_count, len)
      end)

    %__MODULE__{
      src: src,
      start_length: start_length,
      end_length: end_length,
      variants: variants,
      count: count
    }
  end

  def count(%__MODULE__{count: count}), do: count

  def src(%__MODULE__{src: src}), do: src

  def get(%__MODULE__{} = token, index) do
    cond do
      index > token.count - 1 or index < 0 ->
        ""

      index == 0 and token.start_length == 0 ->
        ""

      true ->
        variant_count = length(token.variants)

        {string_length, index_with_offset} =
          Enum.reduce_while(token.start_length..token.end_length, {token.start_length, index}, fn len,
                                                                                                 {_sl, idx} ->
            offset_count = int_pow(variant_count, len)

            if idx < offset_count do
              {:halt, {len, idx}}
            else
              {:cont, {len, idx - offset_count}}
            end
          end)

        build_string(token.variants, string_length, index_with_offset)
    end
  end

  defp build_string(variants, string_length, index) do
    variant_count = length(variants)

    {chars, _} =
      Enum.reduce(1..string_length, {[], index}, fn _, {acc, idx} ->
        variant_index = rem(idx, variant_count)
        {[Enum.at(variants, variant_index) | acc], div(idx, variant_count)}
      end)

    chars |> Enum.reverse() |> Enum.join()
  end

  defp default_integer(option, _fallback) when is_integer(option) and option >= 0, do: option
  defp default_integer(_, fallback), do: fallback

  defp int_pow(_base, 0), do: 1

  defp int_pow(base, exp) when is_integer(exp) and exp > 0 do
    Enum.reduce(1..exp, 1, fn _, acc -> acc * base end)
  end
end
