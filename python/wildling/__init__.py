from __future__ import annotations

from typing import List, Optional, Union

from .generator import Generator, create_generator
from .parse_pattern import Dictionaries

__version__ = "1.0.0"

WildlingResult = Union[str, bool]


class Wildling:
    def __init__(
        self,
        patterns: List[str],
        dictionaries: Optional[Dictionaries] = None,
    ) -> None:
        self._dictionaries: Dictionaries = dictionaries or {}
        self._generators = [
            create_generator(pattern, self._dictionaries) for pattern in patterns
        ]
        self._pattern_count = sum(generator.count() for generator in self._generators)
        self._internal_index = 0

    def index(self) -> int:
        return self._internal_index

    def count(self) -> int:
        return self._pattern_count

    def reset(self) -> None:
        self._internal_index = 0

    def next(self) -> WildlingResult:
        if self._internal_index == self._pattern_count:
            return False
        self._internal_index += 1
        return self.get(self._internal_index - 1)

    def generators(self) -> List[Generator]:
        return self._generators

    def get(self, index: int) -> WildlingResult:
        if index > self._pattern_count - 1 or index < 0:
            return False

        segment_index = 0
        for generator in self._generators:
            pattern_index = index - segment_index
            if pattern_index < generator.count():
                return generator.get(pattern_index)
            segment_index += generator.count()
        return False


def create_wildling(
    patterns: List[str],
    dictionaries: Optional[Dictionaries] = None,
) -> Wildling:
    return Wildling(patterns, dictionaries)


# Alias matching the JavaScript default export name in docs
createWildling = create_wildling
