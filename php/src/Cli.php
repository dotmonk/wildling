<?php

declare(strict_types=1);

namespace Wildling;

final class Cli
{
    /**
     * @return array{0: int, 1: int}|null
     */
    private static function parseRange(string $value): ?array
    {
        $parts = explode('-', $value, 2);
        if (count($parts) !== 2 || !ctype_digit($parts[0]) || !ctype_digit($parts[1])) {
            return null;
        }
        $start = (int) $parts[0];
        $end = (int) $parts[1];
        return $start <= $end ? [$start, $end] : null;
    }

    /**
     * @return list<string>
     */
    private static function loadDictionaryFile(string $path): array
    {
        $content = file_get_contents($path);
        if ($content === false) {
            return [];
        }
        $lines = preg_split('/\r\n|\r|\n/', $content) ?: [];
        $out = [];
        foreach ($lines as $line) {
            $trimmed = trim($line);
            if ($trimmed !== '') {
                $out[] = $trimmed;
            }
        }
        return $out;
    }

    /**
     * @param array{
     *   selects: list<int>,
     *   ranges: list<array{0: int, 1: int}>,
     *   check: bool,
     *   dictionaries: array<string, list<string>>,
     *   patterns: list<string>,
     *   help: bool,
     *   version: bool
     * } $result
     * @param string|list<mixed> $value
     */
    private static function applyDictionary(array &$result, string $name, string|array $value): void
    {
        if (is_array($value)) {
            $words = [];
            foreach ($value as $item) {
                $words[] = (string) $item;
            }
            $result['dictionaries'][$name] = $words;
            return;
        }

        if (is_string($value) && is_file($value)) {
            try {
                $result['dictionaries'][$name] = self::loadDictionaryFile($value);
            } catch (\Throwable) {
                // ignore unreadable dictionary files
            }
        }
    }

    /**
     * @param array{
     *   selects: list<int>,
     *   ranges: list<array{0: int, 1: int}>,
     *   check: bool,
     *   dictionaries: array<string, list<string>>,
     *   patterns: list<string>,
     *   help: bool,
     *   version: bool
     * } $result
     */
    private static function applyTemplate(array &$result, string $path): void
    {
        if (!is_file($path)) {
            fwrite(STDERR, "Template file not found: {$path}\n");
            exit(1);
        }

        $raw = file_get_contents($path);
        if ($raw === false) {
            fwrite(STDERR, "Invalid JSON template: {$path}\n");
            exit(1);
        }

        try {
            $template = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            fwrite(STDERR, "Invalid JSON template: {$path}\n");
            exit(1);
        }

        if (!is_array($template)) {
            fwrite(STDERR, "Invalid JSON template: {$path}\n");
            exit(1);
        }

        if (($template['check'] ?? false) === true) {
            $result['check'] = true;
        }

        if (isset($template['select']) && is_array($template['select'])) {
            foreach ($template['select'] as $val) {
                if (is_int($val) || (is_string($val) && ctype_digit($val))) {
                    $number = (int) $val;
                    if ($number >= 0) {
                        $result['selects'][] = $number;
                    }
                }
            }
        }

        if (isset($template['range']) && is_array($template['range'])) {
            foreach ($template['range'] as $rangeStr) {
                $parsed = self::parseRange((string) $rangeStr);
                if ($parsed !== null) {
                    $result['ranges'][] = $parsed;
                }
            }
        }

        if (isset($template['dictionaries']) && is_array($template['dictionaries'])) {
            foreach ($template['dictionaries'] as $name => $value) {
                if (is_string($value) || is_array($value)) {
                    self::applyDictionary($result, (string) $name, $value);
                }
            }
        }

        if (isset($template['patterns']) && is_array($template['patterns'])) {
            foreach ($template['patterns'] as $pattern) {
                $result['patterns'][] = (string) $pattern;
            }
        }
    }

    /**
     * @param list<string> $args
     * @return array{
     *   selects: list<int>,
     *   ranges: list<array{0: int, 1: int}>,
     *   check: bool,
     *   dictionaries: array<string, list<string>>,
     *   patterns: list<string>,
     *   help: bool,
     *   version: bool
     * }
     */
    private static function parseArgs(array $args): array
    {
        $result = [
            'selects' => [],
            'ranges' => [],
            'check' => false,
            'dictionaries' => [],
            'patterns' => [],
            'help' => false,
            'version' => false,
        ];

        $i = 0;
        $count = count($args);
        while ($i < $count) {
            $arg = $args[$i];

            if ($arg === '--help' || $arg === '-h') {
                $result['help'] = true;
                $i++;
                continue;
            }

            if ($arg === '--version' || $arg === '-v') {
                $result['version'] = true;
                $i++;
                continue;
            }

            if ($arg === '--check') {
                $result['check'] = true;
                $i++;
                continue;
            }

            if ($arg === '--select') {
                $i++;
                if ($i >= $count) {
                    break;
                }
                if (ctype_digit($args[$i]) || (is_numeric($args[$i]) && (int) $args[$i] >= 0 && (string) (int) $args[$i] === $args[$i])) {
                    $val = (int) $args[$i];
                    if ($val >= 0) {
                        $result['selects'][] = $val;
                    }
                }
                $i++;
                continue;
            }

            if ($arg === '--range') {
                $i++;
                if ($i >= $count) {
                    break;
                }
                $parsed = self::parseRange($args[$i]);
                if ($parsed !== null) {
                    $result['ranges'][] = $parsed;
                }
                $i++;
                continue;
            }

            if ($arg === '--dictionary') {
                $i++;
                if ($i >= $count) {
                    break;
                }
                $parts = explode(':', $args[$i], 2);
                if (count($parts) === 2 && $parts[0] !== '' && $parts[1] !== '') {
                    self::applyDictionary($result, $parts[0], $parts[1]);
                }
                $i++;
                continue;
            }

            if ($arg === '--template') {
                $i++;
                if ($i >= $count) {
                    fwrite(STDERR, "Missing path for --template\n");
                    exit(1);
                }
                self::applyTemplate($result, $args[$i]);
                $i++;
                continue;
            }

            $result['patterns'][] = $arg;
            $i++;
        }

        return $result;
    }

    private static function loadHelpText(): string
    {
        $here = dirname(__DIR__);
        $candidates = [
            $here . '/help.txt',
            $here . '/../docs/help.txt',
        ];
        foreach ($candidates as $path) {
            if (is_file($path)) {
                $content = file_get_contents($path);
                if ($content !== false) {
                    return $content;
                }
            }
        }
        return "wildling - pattern based string generator\n\nHelp text unavailable.\n";
    }

    /**
     * @param list<string|int> $values
     */
    private static function formatList(array $values): string
    {
        if ($values === []) {
            return '';
        }
        return ' ' . implode(' ', array_map(static fn ($v): string => (string) $v, $values));
    }

    /**
     * @param array{
     *   selects: list<int>,
     *   ranges: list<array{0: int, 1: int}>,
     *   check: bool,
     *   dictionaries: array<string, list<string>>,
     *   patterns: list<string>,
     *   help: bool,
     *   version: bool
     * } $args
     * @param list<Generator> $generators
     */
    private static function formatCheckOutput(array $args, int $total, array $generators): string
    {
        $ranges = [];
        foreach ($args['ranges'] as [$start, $end]) {
            $ranges[] = "{$start}-{$end}";
        }

        $lines = [
            'patterns:' . self::formatList($args['patterns']),
            'dictionaries:' . self::formatList(array_keys($args['dictionaries'])),
            'select:' . self::formatList($args['selects']),
            'range:' . self::formatList($ranges),
            'total: ' . $total,
        ];
        foreach ($generators as $gen) {
            $lines[] = 'generator: ' . $gen->source . ' ' . $gen->count();
        }
        return implode("\n", $lines);
    }

    /**
     * @param list<string> $argv
     */
    public static function main(array $argv): void
    {
        // Drop script name
        array_shift($argv);
        $args = self::parseArgs(array_values($argv));

        if ($args['help']) {
            echo rtrim(self::loadHelpText()) . "\n";
            exit(0);
        }

        if ($args['version']) {
            echo 'wildling ' . Wildling::VERSION . "\n";
            exit(0);
        }

        if ($args['patterns'] === []) {
            fwrite(STDERR, "No pattern provided. Use --help for usage information.\n");
            exit(1);
        }

        $wildcard = Wildling::create($args['patterns'], $args['dictionaries']);

        if ($args['check']) {
            echo self::formatCheckOutput($args, $wildcard->count(), $wildcard->generators()) . "\n";
            exit(0);
        }

        if ($args['selects'] !== [] || $args['ranges'] !== []) {
            $oor = false;
            foreach ($args['selects'] as $index) {
                $value = $wildcard->get($index);
                if ($value === false) {
                    fwrite(STDERR, "out of range: {$index}\n");
                    $oor = true;
                } else {
                    echo $value . "\n";
                }
            }
            foreach ($args['ranges'] as [$start, $end]) {
                for ($index = $start; $index <= $end; $index++) {
                    $value = $wildcard->get($index);
                    if ($value === false) {
                        fwrite(STDERR, "out of range: {$index}\n");
                        $oor = true;
                    } else {
                        echo $value . "\n";
                    }
                }
            }
            exit($oor ? 1 : 0);
        }

        $value = $wildcard->next();
        while ($value !== false) {
            echo $value . "\n";
            $value = $wildcard->next();
        }
    }
}
