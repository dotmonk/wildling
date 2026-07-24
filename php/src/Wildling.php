<?php

declare(strict_types=1);

namespace Wildling;

final class Wildling
{
    public const VERSION = '2.0.3';

    /** @var list<Generator> */
    private array $generators;
    private int $patternCount;
    private int $internalIndex = 0;

    /**
     * @param list<string> $patterns
     * @param array<string, list<string>>|null $dictionaries
     */
    public function __construct(array $patterns, ?array $dictionaries = null)
    {
        $dictionaries ??= [];
        $this->generators = [];
        $total = 0;
        foreach ($patterns as $pattern) {
            $generator = new Generator($pattern, $dictionaries);
            $this->generators[] = $generator;
            $total += $generator->count();
        }
        $this->patternCount = $total;
    }

    /**
     * @param list<string> $patterns
     * @param array<string, list<string>>|null $dictionaries
     */
    public static function create(array $patterns, ?array $dictionaries = null): self
    {
        return new self($patterns, $dictionaries);
    }

    public function index(): int
    {
        return $this->internalIndex;
    }

    public function count(): int
    {
        return $this->patternCount;
    }

    public function reset(): void
    {
        $this->internalIndex = 0;
    }

    /**
     * @return string|false
     */
    public function next(): string|false
    {
        if ($this->internalIndex === $this->patternCount) {
            return false;
        }
        $this->internalIndex += 1;
        return $this->get($this->internalIndex - 1);
    }

    /**
     * @return list<Generator>
     */
    public function generators(): array
    {
        return $this->generators;
    }

    /**
     * @return string|false
     */
    public function get(int $index): string|false
    {
        if ($index > $this->patternCount - 1 || $index < 0) {
            return false;
        }

        $segmentIndex = 0;
        foreach ($this->generators as $generator) {
            $patternIndex = $index - $segmentIndex;
            if ($patternIndex < $generator->count()) {
                return $generator->get($patternIndex);
            }
            $segmentIndex += $generator->count();
        }

        return false;
    }
}
