defmodule Wildling.Cli do
  @moduledoc false

  defmodule Args do
    @moduledoc false
    defstruct selects: [],
              ranges: [],
              check: false,
              dictionaries: %{},
              patterns: [],
              help: false,
              version: false
  end

  def main(argv \\ nil) do
    args = parse_args(argv || System.argv())

    cond do
      args.help ->
        IO.puts(String.trim_trailing(load_help_text()))
        System.halt(0)

      args.version ->
        IO.puts("wildling #{Wildling.version()}")
        System.halt(0)

      args.patterns == [] ->
        IO.puts(:stderr, "No pattern provided. Use --help for usage information.")
        System.halt(1)

      true ->
        run(args)
    end
  end

  defp run(args) do
    wildcard = Wildling.create(args.patterns, args.dictionaries)

    cond do
      args.check ->
        IO.puts(format_check_output(args, Wildling.count(wildcard), Wildling.generators(wildcard)))
        System.halt(0)

      args.selects != [] or args.ranges != [] ->
        Enum.each(args.selects, fn index ->
          IO.puts(Wildling.get(wildcard, index))
        end)

        Enum.each(args.ranges, fn {start, finish} ->
          Enum.each(start..finish, fn index ->
            IO.puts(Wildling.get(wildcard, index))
          end)
        end)

        System.halt(0)

      true ->
        print_all(wildcard)
        System.halt(0)
    end
  end

  defp print_all(wildcard) do
    value = Wildling.next(wildcard)

    if value != false do
      IO.puts(value)
      print_all(wildcard)
    end
  end

  def parse_args(argv) do
    do_parse_args(argv, %Args{})
  end

  defp do_parse_args([], result), do: result

  defp do_parse_args([arg | rest], result) do
    case arg do
      flag when flag in ["--help", "-h"] ->
        do_parse_args(rest, %{result | help: true})

      flag when flag in ["--version", "-v"] ->
        do_parse_args(rest, %{result | version: true})

      "--check" ->
        do_parse_args(rest, %{result | check: true})

      "--select" ->
        case rest do
          [] ->
            result

          [val | more] ->
            result =
              case Integer.parse(val) do
                {n, ""} when n >= 0 ->
                  %{result | selects: result.selects ++ [n]}

                _ ->
                  result
              end

            do_parse_args(more, result)
        end

      "--range" ->
        case rest do
          [] ->
            result

          [val | more] ->
            result =
              case parse_range(val) do
                nil -> result
                range -> %{result | ranges: result.ranges ++ [range]}
              end

            do_parse_args(more, result)
        end

      "--dictionary" ->
        case rest do
          [] ->
            result

          [val | more] ->
            result =
              case String.split(val, ":", parts: 2) do
                [name, path] when name != "" and path != "" ->
                  apply_dictionary(result, name, path)

                _ ->
                  result
              end

            do_parse_args(more, result)
        end

      "--template" ->
        case rest do
          [] ->
            IO.puts(:stderr, "Missing path for --template")
            System.halt(1)

          [path | more] ->
            do_parse_args(more, apply_template(result, path))
        end

      pattern ->
        do_parse_args(rest, %{result | patterns: result.patterns ++ [pattern]})
    end
  end

  def parse_range(value) do
    case String.split(value, "-", parts: 2) do
      [a, b] ->
        if digits?(a) and digits?(b) do
          start = String.to_integer(a)
          finish = String.to_integer(b)
          if start <= finish, do: {start, finish}, else: nil
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp digits?(s), do: Regex.match?(~r/\A\d+\z/, s)

  def load_dictionary_file(path) do
    path
    |> File.read!()
    |> String.split(~r/\r?\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def apply_dictionary(result, name, value) when is_list(value) do
    dicts = Map.put(result.dictionaries, name, Enum.map(value, &to_string/1))
    %{result | dictionaries: dicts}
  end

  def apply_dictionary(result, name, value) when is_binary(value) do
    if File.exists?(value) do
      try do
        dicts = Map.put(result.dictionaries, name, load_dictionary_file(value))
        %{result | dictionaries: dicts}
      rescue
        _ -> result
      end
    else
      result
    end
  end

  def apply_template(result, path) do
    unless File.exists?(path) do
      IO.puts(:stderr, "Template file not found: #{path}")
      System.halt(1)
    end

    template =
      try do
        path |> File.read!() |> Wildling.Json.parse_object()
      rescue
        _ ->
          IO.puts(:stderr, "Invalid JSON template: #{path}")
          System.halt(1)
      end

    result = if template["check"] == true, do: %{result | check: true}, else: result

    result =
      case template["select"] do
        list when is_list(list) ->
          Enum.reduce(list, result, fn val, acc ->
            try do
              number =
                cond do
                  is_integer(val) -> val
                  is_float(val) -> trunc(val)
                  is_binary(val) -> String.to_integer(val)
                  true -> raise ArgumentError
                end

              if number >= 0 do
                %{acc | selects: acc.selects ++ [number]}
              else
                acc
              end
            rescue
              _ -> acc
            end
          end)

        _ ->
          result
      end

    result =
      case template["range"] do
        list when is_list(list) ->
          Enum.reduce(list, result, fn range_str, acc ->
            case parse_range(to_string(range_str)) do
              nil -> acc
              range -> %{acc | ranges: acc.ranges ++ [range]}
            end
          end)

        _ ->
          result
      end

    result =
      case template["dictionaries"] do
        dicts when is_map(dicts) ->
          Enum.reduce(dicts, result, fn {name, value}, acc ->
            if is_binary(value) or is_list(value) do
              apply_dictionary(acc, to_string(name), value)
            else
              acc
            end
          end)

        _ ->
          result
      end

    case template["patterns"] do
      list when is_list(list) ->
        Enum.reduce(list, result, fn pattern, acc ->
          %{acc | patterns: acc.patterns ++ [to_string(pattern)]}
        end)

      _ ->
        result
    end
  end

  def load_help_text do
    beam = :code.which(__MODULE__)

    beam_dir =
      if is_list(beam) do
        beam |> List.to_string() |> Path.dirname()
      else
        nil
      end

    candidates =
      [
        beam_dir && Path.join(beam_dir, "help.txt"),
        beam_dir && Path.join([beam_dir, "..", "lib", "wildling", "help.txt"]),
        Path.expand(Path.join([__DIR__, "help.txt"])),
        Path.expand(Path.join([__DIR__, "..", "..", "docs", "help.txt"])),
        Path.expand("lib/wildling/help.txt"),
        Path.expand("../docs/help.txt")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.find_value(candidates, fn path ->
      if File.exists?(path), do: File.read!(path)
    end) || "wildling - pattern based string generator\n\nHelp text unavailable.\n"
  end

  def format_list([]), do: ""
  def format_list(nil), do: ""
  def format_list(values), do: " " <> Enum.map_join(values, " ", &to_string/1)

  def format_check_output(args, total, generators) do
    range_strings = Enum.map(args.ranges, fn {s, e} -> "#{s}-#{e}" end)

    lines = [
      "patterns:#{format_list(args.patterns)}",
      "dictionaries:#{format_list(Map.keys(args.dictionaries))}",
      "select:#{format_list(args.selects)}",
      "range:#{format_list(range_strings)}",
      "total: #{total}"
    ]

    gen_lines =
      Enum.map(generators, fn gen ->
        "generator: #{Wildling.Generator.source(gen)} #{Wildling.Generator.count(gen)}"
      end)

    Enum.join(lines ++ gen_lines, "\n")
  end
end
