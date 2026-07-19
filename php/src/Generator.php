<?php

declare(strict_types=1);

namespace Wildling;

final class Generator
{
    public string $source;

    /** @var list<Token> */
    private array $tokens;
    private int $count;

    /**
     * @param array<string, list<string>> $dictionaries
     */
    public function __construct(string $inputPattern, array $dictionaries)
    {
        $this->source = $inputPattern;
        $this->tokens = ParsePattern::parse($inputPattern, $dictionaries);
        $count = 1;
        foreach ($this->tokens as $token) {
            $count *= $token->count();
        }
        $this->count = $count;
    }

    public function count(): int
    {
        return $this->count;
    }

    /**
     * @return list<Token>
     */
    public function tokens(): array
    {
        return $this->tokens;
    }

    public function get(int $index): string
    {
        if ($index > $this->count - 1 || $index < 0) {
            return '';
        }

        $parts = [];
        $indexWithOffset = $index;
        foreach ($this->tokens as $token) {
            $parts[] = $token->get($indexWithOffset % $token->count());
            $indexWithOffset = intdiv($indexWithOffset, $token->count());
        }

        return implode('', $parts);
    }
}
