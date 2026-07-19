use crate::json::{parse as parse_json, JsonValue};
use crate::parse_pattern::Dictionaries;
use crate::wildling::{Wildling, VERSION};
use std::env;
use std::fs;
use std::path::Path;
use std::process;

#[derive(Default)]
struct CliArgs {
    selects: Vec<i32>,
    ranges: Vec<(i32, i32)>,
    check: bool,
    dictionaries: Dictionaries,
    patterns: Vec<String>,
    help: bool,
    version: bool,
}

fn parse_range(value: &str) -> Option<(i32, i32)> {
    let (left, right) = value.split_once('-')?;
    if left.is_empty() || right.is_empty() {
        return None;
    }
    if !left.chars().all(|c| c.is_ascii_digit()) || !right.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let start: i32 = left.parse().ok()?;
    let end: i32 = right.parse().ok()?;
    if start <= end {
        Some((start, end))
    } else {
        None
    }
}

fn load_dictionary_file(path: &str) -> Option<Vec<String>> {
    let content = fs::read_to_string(path).ok()?;
    Some(
        content
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty())
            .map(str::to_string)
            .collect(),
    )
}

fn apply_dictionary(result: &mut CliArgs, name: &str, value: &JsonValue) {
    match value {
        JsonValue::Array(items) => {
            let words = items
                .iter()
                .map(|item| match item {
                    JsonValue::String(s) => s.clone(),
                    JsonValue::Number(n) => format!("{}", *n as i64),
                    JsonValue::Bool(b) => b.to_string(),
                    _ => String::new(),
                })
                .filter(|s| !s.is_empty())
                .collect();
            result.dictionaries.insert(name.to_string(), words);
        }
        JsonValue::String(path) => {
            if Path::new(path).exists() {
                if let Some(words) = load_dictionary_file(path) {
                    result.dictionaries.insert(name.to_string(), words);
                }
            }
        }
        _ => {}
    }
}

fn apply_dictionary_path(result: &mut CliArgs, name: &str, path: &str) {
    if Path::new(path).exists() {
        if let Some(words) = load_dictionary_file(path) {
            result.dictionaries.insert(name.to_string(), words);
        }
    }
}

fn apply_template(result: &mut CliArgs, path: &str) {
    let raw = match fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => {
            eprintln!("Template file not found: {path}");
            process::exit(1);
        }
    };
    let root = match parse_json(&raw) {
        Ok(JsonValue::Object(obj)) => obj,
        _ => {
            eprintln!("Invalid JSON template: {path}");
            process::exit(1);
        }
    };

    if let Some(JsonValue::Bool(true)) = root.get("check") {
        result.check = true;
    }

    if let Some(JsonValue::Array(select)) = root.get("select") {
        for val in select {
            let number = match val {
                JsonValue::Number(n) => Some(*n as i32),
                JsonValue::String(s) => s.parse().ok(),
                _ => None,
            };
            if let Some(n) = number {
                if n >= 0 {
                    result.selects.push(n);
                }
            }
        }
    }

    if let Some(JsonValue::Array(ranges)) = root.get("range") {
        for range_val in ranges {
            if let JsonValue::String(s) = range_val {
                if let Some(r) = parse_range(s) {
                    result.ranges.push(r);
                }
            }
        }
    }

    if let Some(JsonValue::Object(dicts)) = root.get("dictionaries") {
        for (name, value) in dicts {
            apply_dictionary(result, name, value);
        }
    }

    if let Some(JsonValue::Array(patterns)) = root.get("patterns") {
        for pattern in patterns {
            if let JsonValue::String(s) = pattern {
                result.patterns.push(s.clone());
            }
        }
    }
}

fn parse_args(args: &[String]) -> CliArgs {
    let mut result = CliArgs::default();
    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        match arg.as_str() {
            "--help" | "-h" => {
                result.help = true;
                i += 1;
            }
            "--version" | "-v" => {
                result.version = true;
                i += 1;
            }
            "--check" => {
                result.check = true;
                i += 1;
            }
            "--select" => {
                i += 1;
                if i >= args.len() {
                    break;
                }
                if let Ok(val) = args[i].parse::<i32>() {
                    if val >= 0 {
                        result.selects.push(val);
                    }
                }
                i += 1;
            }
            "--range" => {
                i += 1;
                if i >= args.len() {
                    break;
                }
                if let Some(r) = parse_range(&args[i]) {
                    result.ranges.push(r);
                }
                i += 1;
            }
            "--dictionary" => {
                i += 1;
                if i >= args.len() {
                    break;
                }
                if let Some((name, path)) = args[i].split_once(':') {
                    if !name.is_empty() && !path.is_empty() {
                        apply_dictionary_path(&mut result, name, path);
                    }
                }
                i += 1;
            }
            "--template" => {
                i += 1;
                if i >= args.len() {
                    eprintln!("Missing path for --template");
                    process::exit(1);
                }
                apply_template(&mut result, &args[i]);
                i += 1;
            }
            _ => {
                result.patterns.push(arg.clone());
                i += 1;
            }
        }
    }
    result
}

fn load_help_text() -> String {
    let mut candidates = Vec::new();
    if let Ok(exe) = env::current_exe() {
        if let Some(dir) = exe.parent() {
            candidates.push(dir.join("help.txt"));
            candidates.push(dir.join("../docs/help.txt"));
        }
    }
    candidates.push(Path::new("docs/help.txt").to_path_buf());

    for path in candidates {
        if let Ok(content) = fs::read_to_string(&path) {
            return content;
        }
    }
    "wildling - pattern based string generator\n\nHelp text unavailable.\n".to_string()
}

fn format_list(values: &[String]) -> String {
    if values.is_empty() {
        String::new()
    } else {
        format!(" {}", values.join(" "))
    }
}

fn format_check_output(args: &CliArgs, total: i32, generators: &[crate::Generator]) -> String {
    let dict_names: Vec<String> = args.dictionaries.keys().cloned().collect();
    let selects: Vec<String> = args.selects.iter().map(|s| s.to_string()).collect();
    let ranges: Vec<String> = args
        .ranges
        .iter()
        .map(|(a, b)| format!("{a}-{b}"))
        .collect();

    let mut lines = vec![
        format!("patterns:{}", format_list(&args.patterns)),
        format!("dictionaries:{}", format_list(&dict_names)),
        format!("select:{}", format_list(&selects)),
        format!("range:{}", format_list(&ranges)),
        format!("total: {total}"),
    ];
    for gen in generators {
        lines.push(format!("generator: {} {}", gen.source, gen.count()));
    }
    lines.join("\n")
}

pub fn run_cli(args: &[String]) -> i32 {
    let parsed = parse_args(args);

    if parsed.help {
        println!("{}", load_help_text().trim_end());
        return 0;
    }

    if parsed.version {
        println!("wildling {VERSION}");
        return 0;
    }

    if parsed.patterns.is_empty() {
        eprintln!("No pattern provided. Use --help for usage information.");
        return 1;
    }

    let mut wildcard = Wildling::new(&parsed.patterns, &parsed.dictionaries);

    if parsed.check {
        println!(
            "{}",
            format_check_output(&parsed, wildcard.count(), wildcard.generators())
        );
        return 0;
    }

    if !parsed.selects.is_empty() || !parsed.ranges.is_empty() {
        let mut oor = false;
        for index in &parsed.selects {
            match wildcard.get(*index) {
                Some(value) => println!("{value}"),
                None => {
                    eprintln!("out of range: {index}");
                    oor = true;
                }
            }
        }
        for (start, end) in &parsed.ranges {
            for index in *start..=*end {
                match wildcard.get(index) {
                    Some(value) => println!("{value}"),
                    None => {
                        eprintln!("out of range: {index}");
                        oor = true;
                    }
                }
            }
        }
        return if oor { 1 } else { 0 };
    }

    while let Some(value) = wildcard.next() {
        println!("{value}");
    }
    0
}
