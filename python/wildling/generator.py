from __future__ import annotations

from typing import List

from .parse_pattern import Dictionaries, parse_pattern
from .token import Token


class Generator:
    def __init__(self, input_pattern: str, dictionaries: Dictionaries) -> None:
        self.source = input_pattern
        self._tokens = parse_pattern(input_pattern, dictionaries)
        self._count = 1
        for token in self._tokens:
            self._count *= token.count()

    def count(self) -> int:
        return self._count

    def tokens(self) -> List[Token]:
        return self._tokens

    def get(self, index: int) -> str:
        if index > self._count - 1 or index < 0:
            return ""

        string_array: List[str] = []
        index_with_offset = index
        for token in self._tokens:
            string_array.append(token.get(index_with_offset % token.count()))
            index_with_offset //= token.count()
        return "".join(string_array)


def create_generator(input_pattern: str, dictionaries: Dictionaries) -> Generator:
    return Generator(input_pattern, dictionaries)
