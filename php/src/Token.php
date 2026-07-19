<?php

declare(strict_types=1);

namespace Wildling;

final class Token
{
    private string $src;
    private int $startLength;
    private int $endLength;
    /** @var list<string> */
    private array $variants;
    private int $count;

    /**
     * @param array{
     *   string?: string,
     *   startLength?: int,
     *   endLength?: int,
     *   variants?: list<string>,
     *   src?: string
     * } $options
     */
    public function __construct(array $options)
    {
        $this->src = $options['src'] ?? '';
        $this->startLength = self::defaultInteger($options['startLength'] ?? null, 1);
        $this->endLength = self::defaultInteger($options['endLength'] ?? null, 1);
        $this->variants = $options['variants'] ?? [];

        $count = 0;
        for ($length = $this->startLength; $length <= $this->endLength; $length++) {
            $count += self::powInt(count($this->variants), $length);
        }
        $this->count = $count;
    }

    private static function defaultInteger(mixed $option, int $fallback): int
    {
        return is_int($option) && $option >= 0 ? $option : $fallback;
    }

    private static function powInt(int $base, int $exp): int
    {
        $result = 1;
        for ($i = 0; $i < $exp; $i++) {
            $result *= $base;
        }
        return $result;
    }

    public function count(): int
    {
        return $this->count;
    }

    public function src(): string
    {
        return $this->src;
    }

    public function get(int $index): string
    {
        if ($index > $this->count - 1 || $index < 0) {
            return '';
        }

        if ($index === 0 && $this->startLength === 0) {
            return '';
        }

        $indexWithOffset = $index;
        $stringLength = $this->startLength;
        for ($stringLength = $this->startLength; $stringLength <= $this->endLength; $stringLength++) {
            $offsetCount = self::powInt(count($this->variants), $stringLength);
            if ($indexWithOffset < $offsetCount) {
                break;
            }
            $indexWithOffset -= $offsetCount;
        }

        $parts = [];
        for ($i = 0; $i < $stringLength; $i++) {
            $variantIndex = $indexWithOffset % count($this->variants);
            $indexWithOffset = intdiv($indexWithOffset, count($this->variants));
            $parts[] = $this->variants[$variantIndex];
        }

        return implode('', $parts);
    }
}
