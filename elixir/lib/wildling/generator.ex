defmodule Wildling.Generator do
  @moduledoc false

  alias Wildling.ParsePattern
  alias Wildling.Token

  defstruct source: "", tokens: [], count: 1

  def new(input_pattern, dictionaries \\ %{}) do
    tokens = ParsePattern.parse_pattern(input_pattern, dictionaries || %{})

    count =
      Enum.reduce(tokens, 1, fn token, acc ->
        acc * Token.count(token)
      end)

    %__MODULE__{source: input_pattern, tokens: tokens, count: count}
  end

  def count(%__MODULE__{count: count}), do: count

  def source(%__MODULE__{source: source}), do: source

  def tokens(%__MODULE__{tokens: tokens}), do: tokens

  def get(%__MODULE__{} = generator, index) do
    if index > generator.count - 1 or index < 0 do
      ""
    else
      {parts, _} =
        Enum.reduce(generator.tokens, {[], index}, fn token, {acc, idx} ->
          token_count = Token.count(token)
          {[Token.get(token, rem(idx, token_count)) | acc], div(idx, token_count)}
        end)

      parts |> Enum.reverse() |> Enum.join()
    end
  end
end
