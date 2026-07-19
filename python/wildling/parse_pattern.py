from __future__ import annotations

import re
from typing import Callable, Dict, List, Union

from .token import Token, TokenOptions, create_token

Dictionaries = Dict[str, List[str]]

TOKEN_PARSING_REGEX = re.compile(
    r"(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])"
)


def parse_length_with_variants(part: str, variants: List[str]) -> TokenOptions:
    length_arg_regex = re.compile(r"\{((\d+)-(\d+)|(\d+))\}")
    match = length_arg_regex.search(part)

    start_length = 1
    end_length = 1

    if match is not None and match.group(2):
        start_length = int(match.group(2))
        end_length = int(match.group(3))
    elif match is not None and match.group(1):
        start_length = int(match.group(1))
        end_length = start_length

    return {
        "variants": variants,
        "startLength": start_length,
        "endLength": end_length,
        "src": part,
    }


def parse_length_with_string(part: str) -> Union[TokenOptions, bool]:
    length_arg_regex = re.compile(r"\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}")
    match = length_arg_regex.search(part)

    if match is None:
        return False

    if match.group(2) is not None and match.group(3) is not None:
        return {
            "string": match.group(1) or "",
            "startLength": int(match.group(2)),
            "endLength": int(match.group(3)),
            "src": part,
        }

    if match.group(4) is not None:
        length = int(match.group(4))
        return {
            "string": match.group(1) or "",
            "startLength": length,
            "endLength": length,
            "src": part,
        }

    return {
        "string": match.group(1) or "",
        "startLength": 1,
        "endLength": 1,
        "src": part,
    }


def simple_tokenizer(variants_string: str) -> Callable[[str], Token]:
    variants = list(variants_string)

    def tokenizer(part: str) -> Token:
        return create_token(parse_length_with_variants(part, variants))

    return tokenizer


def _dictionary_tokenizer(part: str, dictionaries: Dictionaries) -> Token:
    options = parse_length_with_string(part)
    if options is False or (
        isinstance(options, dict)
        and options.get("string")
        and options["string"] not in dictionaries
    ):
        options = {
            "variants": [part],
            "startLength": 1,
            "endLength": 1,
            "src": part,
        }
    else:
        assert isinstance(options, dict)
        options["variants"] = dictionaries.get(options.get("string") or "", [])
    return create_token(options)


def _words_tokenizer(part: str) -> Token:
    options = parse_length_with_string(part)

    if options is False:
        options = {
            "variants": [part],
            "startLength": 1,
            "endLength": 1,
            "src": part,
        }
    else:
        assert isinstance(options, dict)
        variants: List[str] = []
        work_string = options.get("string") or ""
        index = 0
        while index < len(work_string):
            if work_string[index : index + 2] == "\\,":
                index += 2
            elif work_string[index] == ",":
                variants.append(work_string[:index])
                work_string = work_string[index + 1 :]
                index = 0
            else:
                index += 1
        variants.append(work_string)
        options["variants"] = [variant.replace("\\,", ",") for variant in variants]

    return create_token(options)


def part_to_token(part: str, dictionaries: Dictionaries) -> Token:
    tokenizers: Dict[str, Callable[[str], Token]] = {
        "#": simple_tokenizer("0123456789"),
        "@": simple_tokenizer("abcdefghijklmnopqrstuvwxyz"),
        "*": simple_tokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
        "-": simple_tokenizer(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        ),
        "!": simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        "?": simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
        "&": simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        "%": lambda p: _dictionary_tokenizer(p, dictionaries),
        "$": _words_tokenizer,
    }

    tokenizer = tokenizers.get(part[0]) if part else None
    is_escaped_token = (
        len(part) > 1 and part[0] == "\\" and part[1] in tokenizers
    )

    if tokenizer is not None:
        return tokenizer(part)
    if is_escaped_token:
        return create_token(
            {
                "variants": [re.sub(r"^\\", "", part)],
                "src": part,
            }
        )
    return create_token({"variants": [part], "src": part})


def parse_pattern(input_pattern: str, dictionaries: Dictionaries) -> List[Token]:
    parts = [part for part in TOKEN_PARSING_REGEX.split(input_pattern) if part]
    return [part_to_token(part, dictionaries) for part in parts]
