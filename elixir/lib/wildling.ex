defmodule Wildling do
  @moduledoc """
  Pattern-based string generator.
  """

  alias Wildling.Generator

  @version "2.0.5"

  defstruct generators: [], pattern_count: 0, internal_index: 0

  def version, do: @version

  @doc """
  Create a wildling client (Agent pid) for the given patterns and dictionaries.
  """
  def create(patterns, dictionaries \\ %{}) do
    dictionaries = dictionaries || %{}
    patterns = patterns || []

    generators = Enum.map(patterns, &Generator.new(&1, dictionaries))

    pattern_count =
      Enum.reduce(generators, 0, fn gen, acc -> acc + Generator.count(gen) end)

    state = %__MODULE__{
      generators: generators,
      pattern_count: pattern_count,
      internal_index: 0
    }

    {:ok, pid} = Agent.start_link(fn -> state end)
    pid
  end

  def index(client) when is_pid(client) do
    Agent.get(client, & &1.internal_index)
  end

  def count(client) when is_pid(client) do
    Agent.get(client, & &1.pattern_count)
  end

  def reset(client) when is_pid(client) do
    Agent.update(client, fn state -> %{state | internal_index: 0} end)
  end

  @doc """
  Next combination, or `false` when exhausted.
  """
  def next(client) when is_pid(client) do
    Agent.get_and_update(client, fn state ->
      if state.internal_index == state.pattern_count do
        {false, state}
      else
        value = do_get(state, state.internal_index)
        {value, %{state | internal_index: state.internal_index + 1}}
      end
    end)
  end

  def generators(client) when is_pid(client) do
    Agent.get(client, & &1.generators)
  end

  @doc """
  Combination at index, or `false` if out of range.
  """
  def get(client, index) when is_pid(client) do
    Agent.get(client, &do_get(&1, index))
  end

  defp do_get(%__MODULE__{} = state, index) do
    if index > state.pattern_count - 1 or index < 0 do
      false
    else
      find_in_generators(state.generators, index, 0)
    end
  end

  defp find_in_generators([], _index, _segment), do: false

  defp find_in_generators([generator | rest], index, segment_index) do
    pattern_index = index - segment_index

    if pattern_index < Generator.count(generator) do
      Generator.get(generator, pattern_index)
    else
      find_in_generators(rest, index, segment_index + Generator.count(generator))
    end
  end
end
