from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Union

from . import __version__, create_wildling
from .generator import Generator

Dictionary = Dict[str, List[str]]


@dataclass
class CliArgs:
    selects: List[int] = field(default_factory=list)
    ranges: List[Tuple[int, int]] = field(default_factory=list)
    check: bool = False
    dictionaries: Dictionary = field(default_factory=dict)
    patterns: List[str] = field(default_factory=list)
    help: bool = False
    version: bool = False


def parse_range(value: str) -> Optional[Tuple[int, int]]:
    parts = value.split("-", 1)
    if len(parts) != 2 or not parts[0].isdigit() or not parts[1].isdigit():
        return None
    start = int(parts[0])
    end = int(parts[1])
    return (start, end) if start <= end else None


def load_dictionary_file(path: str) -> List[str]:
    with open(path, encoding="utf-8") as handle:
        return [line.strip() for line in handle.read().splitlines() if line.strip()]


def apply_dictionary(result: CliArgs, name: str, value: Union[str, List[str]]) -> None:
    if isinstance(value, list):
        result.dictionaries[name] = [str(item) for item in value]
        return
    if isinstance(value, str) and os.path.exists(value):
        try:
            result.dictionaries[name] = load_dictionary_file(value)
        except OSError:
            pass


def apply_template(result: CliArgs, path: str) -> None:
    if not os.path.exists(path):
        print(f"Template file not found: {path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(path, encoding="utf-8") as handle:
            template = json.load(handle)
    except (OSError, json.JSONDecodeError):
        print(f"Invalid JSON template: {path}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(template, dict):
        print(f"Invalid JSON template: {path}", file=sys.stderr)
        sys.exit(1)

    if template.get("check") is True:
        result.check = True

    select = template.get("select")
    if isinstance(select, list):
        for val in select:
            try:
                number = int(val)
            except (TypeError, ValueError):
                continue
            if number >= 0:
                result.selects.append(number)

    ranges = template.get("range")
    if isinstance(ranges, list):
        for range_str in ranges:
            parsed = parse_range(str(range_str))
            if parsed is not None:
                result.ranges.append(parsed)

    dictionaries = template.get("dictionaries")
    if isinstance(dictionaries, dict):
        for name, value in dictionaries.items():
            if isinstance(value, (str, list)):
                apply_dictionary(result, str(name), value)

    patterns = template.get("patterns")
    if isinstance(patterns, list):
        for pattern in patterns:
            result.patterns.append(str(pattern))


def parse_args(args: List[str]) -> CliArgs:
    result = CliArgs()
    i = 0
    while i < len(args):
        arg = args[i]

        if arg in ("--help", "-h"):
            result.help = True
            i += 1
            continue

        if arg in ("--version", "-v"):
            result.version = True
            i += 1
            continue

        if arg == "--check":
            result.check = True
            i += 1
            continue

        if arg == "--select":
            i += 1
            if i >= len(args):
                break
            try:
                val = int(args[i])
            except ValueError:
                val = -1
            if val >= 0:
                result.selects.append(val)
            i += 1
            continue

        if arg == "--range":
            i += 1
            if i >= len(args):
                break
            parsed = parse_range(args[i])
            if parsed is not None:
                result.ranges.append(parsed)
            i += 1
            continue

        if arg == "--dictionary":
            i += 1
            if i >= len(args):
                break
            name, sep, path = args[i].partition(":")
            if sep and name and path:
                apply_dictionary(result, name, path)
            i += 1
            continue

        if arg == "--template":
            i += 1
            if i >= len(args):
                print("Missing path for --template", file=sys.stderr)
                sys.exit(1)
            apply_template(result, args[i])
            i += 1
            continue

        result.patterns.append(arg)
        i += 1

    return result


def load_help_text() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "help.txt"),
        os.path.join(here, "..", "..", "docs", "help.txt"),
    ]
    for path in candidates:
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                return handle.read()
    return "wildling - pattern based string generator\n\nHelp text unavailable.\n"


def format_list(values: List[Union[str, int]]) -> str:
    return "" if not values else " " + " ".join(str(value) for value in values)


def format_check_output(args: CliArgs, total: int, generators: List[Generator]) -> str:
    lines = [
        f"patterns:{format_list(args.patterns)}",
        f"dictionaries:{format_list(list(args.dictionaries.keys()))}",
        f"select:{format_list(args.selects)}",
        f"range:{format_list([f'{start}-{end}' for start, end in args.ranges])}",
        f"total: {total}",
    ]
    for gen in generators:
        lines.append(f"generator: {gen.source} {gen.count()}")
    return "\n".join(lines)


def print_result(value: object) -> None:
    """Print a result; out-of-range sentinel is lowercase false."""
    if value is False:
        print("false")
    else:
        print(value)


def main(argv: Optional[List[str]] = None) -> None:
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if args.help:
        print(load_help_text().rstrip())
        sys.exit(0)

    if args.version:
        print(f"wildling {__version__}")
        sys.exit(0)

    if not args.patterns:
        print("No pattern provided. Use --help for usage information.", file=sys.stderr)
        sys.exit(1)

    wildcard = create_wildling(args.patterns, args.dictionaries)

    if args.check:
        print(format_check_output(args, wildcard.count(), wildcard.generators()))
        sys.exit(0)

    if args.selects or args.ranges:
        for index in args.selects:
            print_result(wildcard.get(index))
        for start, end in args.ranges:
            for index in range(start, end + 1):
                print_result(wildcard.get(index))
        sys.exit(0)

    value = wildcard.next()
    while value is not False:
        print(value)
        value = wildcard.next()


if __name__ == "__main__":
    main()
