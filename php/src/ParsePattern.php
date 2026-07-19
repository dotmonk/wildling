<?php

declare(strict_types=1);

namespace Wildling;

final class ParsePattern
{
    private const TOKEN_PARSING_REGEX = '/(\\\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])/';

    /**
     * @param list<string> $variants
     * @return array{variants: list<string>, startLength: int, endLength: int, src: string}
     */
    private static function parseLengthWithVariants(string $part, array $variants): array
    {
        $startLength = 1;
        $endLength = 1;

        if (preg_match('/\{((\d+)-(\d+)|(\d+))\}/', $part, $match) === 1) {
            if (($match[2] ?? '') !== '') {
                $startLength = (int) $match[2];
                $endLength = (int) $match[3];
            } elseif (($match[1] ?? '') !== '') {
                $startLength = (int) $match[1];
                $endLength = $startLength;
            }
        }

        return [
            'variants' => $variants,
            'startLength' => $startLength,
            'endLength' => $endLength,
            'src' => $part,
        ];
    }

    /**
     * @return array{string: string, startLength: int, endLength: int, src: string}|false
     */
    private static function parseLengthWithString(string $part): array|false
    {
        if (preg_match('/\{\'(.*)\'(?:,(\d+)-(\d+))?(?:,(\d+))?\}/', $part, $match) !== 1) {
            return false;
        }

        if (($match[2] ?? null) !== null && ($match[3] ?? null) !== null && $match[2] !== '' && $match[3] !== '') {
            return [
                'string' => $match[1] ?? '',
                'startLength' => (int) $match[2],
                'endLength' => (int) $match[3],
                'src' => $part,
            ];
        }

        if (($match[4] ?? null) !== null && $match[4] !== '') {
            $length = (int) $match[4];
            return [
                'string' => $match[1] ?? '',
                'startLength' => $length,
                'endLength' => $length,
                'src' => $part,
            ];
        }

        return [
            'string' => $match[1] ?? '',
            'startLength' => 1,
            'endLength' => 1,
            'src' => $part,
        ];
    }

    /**
     * @return callable(string): Token
     */
    private static function simpleTokenizer(string $variantsString): callable
    {
        $variants = str_split($variantsString);

        return static function (string $part) use ($variants): Token {
            return new Token(self::parseLengthWithVariants($part, $variants));
        };
    }

    /**
     * @param array<string, list<string>> $dictionaries
     */
    private static function dictionaryTokenizer(string $part, array $dictionaries): Token
    {
        $options = self::parseLengthWithString($part);
        if ($options === false
            || (($options['string'] ?? '') !== '' && !array_key_exists($options['string'], $dictionaries))
        ) {
            return new Token([
                'variants' => [$part],
                'startLength' => 1,
                'endLength' => 1,
                'src' => $part,
            ]);
        }

        $options['variants'] = $dictionaries[$options['string'] ?? ''] ?? [];
        return new Token($options);
    }

    private static function wordsTokenizer(string $part): Token
    {
        $options = self::parseLengthWithString($part);
        if ($options === false) {
            return new Token([
                'variants' => [$part],
                'startLength' => 1,
                'endLength' => 1,
                'src' => $part,
            ]);
        }

        $variants = [];
        $workString = $options['string'] ?? '';
        $index = 0;
        while ($index < strlen($workString)) {
            if (substr($workString, $index, 2) === '\\,') {
                $index += 2;
            } elseif ($workString[$index] === ',') {
                $variants[] = substr($workString, 0, $index);
                $workString = substr($workString, $index + 1);
                $index = 0;
            } else {
                $index += 1;
            }
        }
        $variants[] = $workString;
        $options['variants'] = array_map(
            static fn (string $variant): string => str_replace('\\,', ',', $variant),
            $variants
        );

        return new Token($options);
    }

    /**
     * @param array<string, list<string>> $dictionaries
     */
    private static function partToToken(string $part, array $dictionaries): Token
    {
        /** @var array<string, callable(string): Token> $tokenizers */
        $tokenizers = [
            '#' => self::simpleTokenizer('0123456789'),
            '@' => self::simpleTokenizer('abcdefghijklmnopqrstuvwxyz'),
            '*' => self::simpleTokenizer('abcdefghijklmnopqrstuvwxyz0123456789'),
            '-' => self::simpleTokenizer(
                'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            ),
            '!' => self::simpleTokenizer('ABCDEFGHIJKLMNOPQRSTUVWXYZ'),
            '?' => self::simpleTokenizer('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'),
            '&' => self::simpleTokenizer('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'),
            '%' => static fn (string $p): Token => self::dictionaryTokenizer($p, $dictionaries),
            '$' => static fn (string $p): Token => self::wordsTokenizer($p),
        ];

        $tokenizer = $part !== '' && isset($tokenizers[$part[0]]) ? $tokenizers[$part[0]] : null;
        $isEscapedToken = strlen($part) > 1 && $part[0] === '\\' && isset($tokenizers[$part[1]]);

        if ($tokenizer !== null) {
            return $tokenizer($part);
        }

        if ($isEscapedToken) {
            return new Token([
                'variants' => [preg_replace('/^\\\\/', '', $part) ?? substr($part, 1)],
                'startLength' => 1,
                'endLength' => 1,
                'src' => $part,
            ]);
        }

        return new Token([
            'variants' => [$part],
            'startLength' => 1,
            'endLength' => 1,
            'src' => $part,
        ]);
    }

    /**
     * @param array<string, list<string>> $dictionaries
     * @return list<Token>
     */
    public static function parse(string $inputPattern, array $dictionaries): array
    {
        $parts = preg_split(self::TOKEN_PARSING_REGEX, $inputPattern, -1, PREG_SPLIT_DELIM_CAPTURE | PREG_SPLIT_NO_EMPTY);
        if ($parts === false) {
            $parts = [$inputPattern];
        }

        $tokens = [];
        foreach ($parts as $part) {
            $tokens[] = self::partToToken($part, $dictionaries);
        }
        return $tokens;
    }
}
