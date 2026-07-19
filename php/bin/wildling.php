#!/usr/bin/env php
<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "wildling CLI must be run from the command line.\n");
    exit(1);
}

\Wildling\Cli::main($argv);
