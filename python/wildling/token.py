from __future__ import annotations

from typing import List, TypedDict


class TokenOptions(TypedDict, total=False):
    string: str
    startLength: int
    endLength: int
    variants: List[str]
    src: str


def _default_integer_option(option: object, fallback: int) -> int:
    return option if isinstance(option, int) and option >= 0 else fallback


class Token:
    def __init__(self, options: TokenOptions) -> None:
        self._src = options.get("src", "")
        self._start_length = _default_integer_option(options.get("startLength"), 1)
        self._end_length = _default_integer_option(options.get("endLength"), 1)
        self._variants = options.get("variants") or []
        self._count = 0
        for length in range(self._start_length, self._end_length + 1):
            self._count += len(self._variants) ** length

    def count(self) -> int:
        return self._count

    def src(self) -> str:
        return self._src

    def get(self, index: int) -> str:
        if index > self._count - 1 or index < 0:
            return ""

        if index == 0 and self._start_length == 0:
            return ""

        index_with_offset = index
        string_length = self._start_length
        for string_length in range(self._start_length, self._end_length + 1):
            offset_count = len(self._variants) ** string_length
            if index_with_offset < offset_count:
                break
            index_with_offset -= offset_count

        string_array: List[str] = []
        for _ in range(string_length):
            variant_index = index_with_offset % len(self._variants)
            index_with_offset //= len(self._variants)
            string_array.append(self._variants[variant_index])
        return "".join(string_array)


def create_token(options: TokenOptions) -> Token:
    return Token(options)
