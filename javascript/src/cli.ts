import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { argv, exit } from "node:process";
import createWildling, { WildlingOptions } from "./index.js";
import type { Generator } from "./createGenerator.js";

type Dictionary = Record<string, string[]>;

interface CliArgs {
  selects: number[];
  ranges: [number, number][];
  check: boolean;
  dictionaries: Dictionary;
  patterns: string[];
  help: boolean;
  version: boolean;
}

interface TemplateFile {
  patterns?: string[];
  dictionaries?: Record<string, string | string[]>;
  select?: number[];
  range?: string[];
  check?: boolean;
}

function parseRange(str: string): [number, number] | null {
  const m = str.match(/^(\d+)-(\d+)$/);
  if (!m) return null;
  const a = Number(m[1]);
  const b = Number(m[2]);
  return a <= b ? [a, b] : null;
}

function loadDictionaryFile(path: string): string[] {
  const content = readFileSync(path, "utf-8");
  return content
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
}

function applyDictionary(result: CliArgs, name: string, value: string | string[]): void {
  if (Array.isArray(value)) {
    result.dictionaries[name] = value.map(String);
    return;
  }
  if (typeof value === "string" && existsSync(value)) {
    try {
      result.dictionaries[name] = loadDictionaryFile(value);
    } catch {
      // ignore unreadable dictionary files
    }
  }
}

function applyTemplate(result: CliArgs, path: string): void {
  if (!existsSync(path)) {
    console.error(`Template file not found: ${path}`);
    exit(1);
  }

  let template: TemplateFile;
  try {
    template = JSON.parse(readFileSync(path, "utf-8")) as TemplateFile;
  } catch {
    console.error(`Invalid JSON template: ${path}`);
    exit(1);
  }

  if (template.check === true) {
    result.check = true;
  }

  if (Array.isArray(template.select)) {
    for (const val of template.select) {
      const n = Number(val);
      if (!Number.isNaN(n) && n >= 0) {
        result.selects.push(n);
      }
    }
  }

  if (Array.isArray(template.range)) {
    for (const rangeStr of template.range) {
      const range = parseRange(String(rangeStr));
      if (range) result.ranges.push(range);
    }
  }

  if (template.dictionaries && typeof template.dictionaries === "object") {
    for (const [name, value] of Object.entries(template.dictionaries)) {
      applyDictionary(result, name, value);
    }
  }

  if (Array.isArray(template.patterns)) {
    for (const pattern of template.patterns) {
      result.patterns.push(String(pattern));
    }
  }
}

function parseArgs(args: string[]): CliArgs {
  const result: CliArgs = {
    selects: [],
    ranges: [],
    check: false,
    dictionaries: {},
    patterns: [],
    help: false,
    version: false,
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i] || "";

    if (arg === "--help" || arg === "-h") {
      result.help = true;
      i++;
      continue;
    }

    if (arg === "--version" || arg === "-v") {
      result.version = true;
      i++;
      continue;
    }

    if (arg === "--check") {
      result.check = true;
      i++;
      continue;
    }

    if (arg === "--select") {
      i++;
      if (i >= args.length) break;
      const val = Number(args[i]);
      if (!Number.isNaN(val) && val >= 0) {
        result.selects.push(val);
      }
      i++;
      continue;
    }

    if (arg === "--range") {
      i++;
      if (i >= args.length) break;
      const range = parseRange(args[i] || "");
      if (range) result.ranges.push(range);
      i++;
      continue;
    }

    if (arg === "--dictionary") {
      i++;
      if (i >= args.length) break;
      const [name, path] = (args[i] || "").split(":", 2);
      if (name && path) {
        applyDictionary(result, name, path);
      }
      i++;
      continue;
    }

    if (arg === "--template") {
      i++;
      if (i >= args.length) {
        console.error("Missing path for --template");
        exit(1);
      }
      applyTemplate(result, args[i] || "");
      i++;
      continue;
    }

    result.patterns.push(arg);
    i++;
  }

  return result;
}

function packageVersion(): string {
  try {
    const pkg = JSON.parse(
      readFileSync(join(__dirname, "..", "package.json"), "utf-8")
    ) as { version?: string };
    return pkg.version || "0.0.0";
  } catch {
    return "0.0.0";
  }
}

function loadHelpText(): string {
  const candidates = [
    join(__dirname, "help.txt"),
    join(__dirname, "..", "..", "docs", "help.txt"),
  ];
  for (const path of candidates) {
    if (existsSync(path)) {
      return readFileSync(path, "utf-8");
    }
  }
  return "wildling - pattern based string generator\n\nHelp text unavailable.\n";
}

function formatList(values: Array<string | number>): string {
  return values.length === 0 ? "" : ` ${values.join(" ")}`;
}

function formatCheckOutput(
  args: CliArgs,
  total: number,
  generators: Generator[]
): string {
  const lines = [
    `patterns:${formatList(args.patterns)}`,
    `dictionaries:${formatList(Object.keys(args.dictionaries))}`,
    `select:${formatList(args.selects)}`,
    `range:${formatList(args.ranges.map(([a, b]) => `${a}-${b}`))}`,
    `total: ${total}`,
  ];
  for (const gen of generators) {
    lines.push(`generator: ${gen.source} ${gen.count()}`);
  }
  return lines.join("\n");
}

function main() {
  const args = parseArgs(argv.slice(2));

  if (args.help) {
    console.log(loadHelpText().replace(/\s+$/, ""));
    exit(0);
  }

  if (args.version) {
    console.log(`wildling ${packageVersion()}`);
    exit(0);
  }

  if (args.patterns.length === 0) {
    console.error("No pattern provided. Use --help for usage information.");
    exit(1);
  }

  const options: WildlingOptions = {
    dictionaries: args.dictionaries,
    patterns: args.patterns,
  };

  const wildcard = createWildling(options);

  if (args.check) {
    console.log(formatCheckOutput(args, wildcard.count(), wildcard.generators()));
    exit(0);
  }

  if (args.selects.length > 0 || args.ranges.length > 0) {
    let oor = false;
    for (const index of args.selects) {
      const value = wildcard.get(index);
      if (value === false) {
        console.error(`out of range: ${index}`);
        oor = true;
      } else {
        console.log(value);
      }
    }
    for (const [start, end] of args.ranges) {
      for (let i = start; i <= end; i++) {
        const value = wildcard.get(i);
        if (value === false) {
          console.error(`out of range: ${i}`);
          oor = true;
        } else {
          console.log(value);
        }
      }
    }
    exit(oor ? 1 : 0);
  }

  let string = wildcard.next();

  // Empty string is a real combination (e.g. #{0-1}); only `false` means exhaustion.
  while (string !== false) {
    console.log(string);
    string = wildcard.next();
  }
}

main();
