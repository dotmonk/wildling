use crate::token::{Token, TokenOptions};
use std::collections::HashMap;

pub type Dictionaries = HashMap<String, Vec<String>>;

fn is_special(c: char) -> bool {
    matches!(c, '#' | '@' | '$' | '*' | '&' | '?' | '!' | '-' | '%')
}

/// Split like JS/Python capturing-group split, without a regex crate.
fn split_keeping_delimiters(input: &str) -> Vec<String> {
    let chars: Vec<char> = input.chars().collect();
    let mut parts = Vec::new();
    let mut i = 0;
    let mut literal_start = 0;

    while i < chars.len() {
        // Escaped special: \X
        if chars[i] == '\\' && i + 1 < chars.len() && is_special(chars[i + 1]) {
            if i > literal_start {
                parts.push(chars[literal_start..i].iter().collect());
            }
            parts.push(chars[i..=i + 1].iter().collect());
            i += 2;
            literal_start = i;
            continue;
        }

        // Special with {…}
        if is_special(chars[i]) && i + 1 < chars.len() && chars[i + 1] == '{' {
            if i > literal_start {
                parts.push(chars[literal_start..i].iter().collect());
            }
            let mut j = i + 2;
            while j < chars.len() && chars[j] != '}' {
                j += 1;
            }
            if j < chars.len() && chars[j] == '}' {
                parts.push(chars[i..=j].iter().collect());
                i = j + 1;
                literal_start = i;
                continue;
            }
        }

        // Bare special
        if is_special(chars[i]) {
            if i > literal_start {
                parts.push(chars[literal_start..i].iter().collect());
            }
            parts.push(chars[i].to_string());
            i += 1;
            literal_start = i;
            continue;
        }

        i += 1;
    }

    if literal_start < chars.len() {
        parts.push(chars[literal_start..].iter().collect());
    }
    parts
}

fn parse_length_with_variants(part: &str, variants: Vec<String>) -> TokenOptions {
    let mut start_length = 1;
    let mut end_length = 1;

    if let Some(open) = part.find('{') {
        if let Some(close) = part[open..].find('}') {
            let inner = &part[open + 1..open + close];
            if let Some(dash) = inner.find('-') {
                if let (Ok(s), Ok(e)) = (
                    inner[..dash].parse::<i32>(),
                    inner[dash + 1..].parse::<i32>(),
                ) {
                    start_length = s;
                    end_length = e;
                }
            } else if let Ok(n) = inner.parse::<i32>() {
                start_length = n;
                end_length = n;
            }
        }
    }

    TokenOptions {
        string: None,
        start_length: Some(start_length),
        end_length: Some(end_length),
        variants,
        src: part.to_string(),
    }
}

fn parse_length_with_string(part: &str) -> Option<TokenOptions> {
    // Match {'...'} with optional ,N-M or ,N — greedy content between quotes.
    let open = part.find("{'")?;
    let after_open = open + 2;
    let rest = &part[after_open..];
    let close_quote = rest.rfind('\'')?;
    let content = &rest[..close_quote];
    let after_quote = &rest[close_quote + 1..];

    if !after_quote.starts_with('}') && !after_quote.starts_with(',') {
        // Must end with } eventually
        if !after_quote.contains('}') {
            return None;
        }
    }

    let mut start_length = 1;
    let mut end_length = 1;

    if let Some(stripped) = after_quote.strip_prefix(',') {
        let before_brace = stripped.strip_suffix('}').unwrap_or(stripped);
        if let Some(dash) = before_brace.find('-') {
            if let (Ok(s), Ok(e)) = (
                before_brace[..dash].parse::<i32>(),
                before_brace[dash + 1..].parse::<i32>(),
            ) {
                start_length = s;
                end_length = e;
            }
        } else if let Ok(n) = before_brace.parse::<i32>() {
            start_length = n;
            end_length = n;
        }
    } else if !after_quote.starts_with('}') {
        return None;
    }

    Some(TokenOptions {
        string: Some(content.to_string()),
        start_length: Some(start_length),
        end_length: Some(end_length),
        variants: Vec::new(),
        src: part.to_string(),
    })
}

fn chars_as_variants(s: &str) -> Vec<String> {
    s.chars().map(|c| c.to_string()).collect()
}

fn simple_tokenizer(part: &str, alphabet: &str) -> Token {
    Token::new(parse_length_with_variants(part, chars_as_variants(alphabet)))
}

fn dictionary_tokenizer(part: &str, dictionaries: &Dictionaries) -> Token {
    match parse_length_with_string(part) {
        Some(mut options)
            if options
                .string
                .as_ref()
                .map(|s| s.is_empty() || dictionaries.contains_key(s))
                .unwrap_or(false) =>
        {
            let key = options.string.clone().unwrap_or_default();
            options.variants = dictionaries.get(&key).cloned().unwrap_or_default();
            Token::new(options)
        }
        _ => Token::new(TokenOptions {
            string: None,
            start_length: Some(1),
            end_length: Some(1),
            variants: vec![part.to_string()],
            src: part.to_string(),
        }),
    }
}

fn words_tokenizer(part: &str) -> Token {
    match parse_length_with_string(part) {
        None => Token::new(TokenOptions {
            string: None,
            start_length: Some(1),
            end_length: Some(1),
            variants: vec![part.to_string()],
            src: part.to_string(),
        }),
        Some(mut options) => {
            let mut variants = Vec::new();
            let mut work_string = options.string.clone().unwrap_or_default();
            let mut index = 0;
            while index < work_string.len() {
                if index + 1 < work_string.len()
                    && work_string.as_bytes()[index] == b'\\'
                    && work_string.as_bytes()[index + 1] == b','
                {
                    index += 2;
                } else if work_string.as_bytes()[index] == b',' {
                    variants.push(work_string[..index].to_string());
                    work_string = work_string[index + 1..].to_string();
                    index = 0;
                } else {
                    index += 1;
                }
            }
            variants.push(work_string);
            options.variants = variants
                .into_iter()
                .map(|v| v.replace("\\,", ","))
                .collect();
            Token::new(options)
        }
    }
}

fn part_to_token(part: &str, dictionaries: &Dictionaries) -> Token {
    let first = part.chars().next();
    match first {
        Some('#') => simple_tokenizer(part, "0123456789"),
        Some('@') => simple_tokenizer(part, "abcdefghijklmnopqrstuvwxyz"),
        Some('*') => simple_tokenizer(part, "abcdefghijklmnopqrstuvwxyz0123456789"),
        Some('-') => simple_tokenizer(
            part,
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
        ),
        Some('!') => simple_tokenizer(part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        Some('?') => simple_tokenizer(part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
        Some('&') => {
            simple_tokenizer(part, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        }
        Some('%') => dictionary_tokenizer(part, dictionaries),
        Some('$') => words_tokenizer(part),
        Some('\\') if part.len() > 1 && is_special(part.chars().nth(1).unwrap()) => {
            Token::new(TokenOptions {
                string: None,
                start_length: Some(1),
                end_length: Some(1),
                variants: vec![part[1..].to_string()],
                src: part.to_string(),
            })
        }
        _ => Token::new(TokenOptions {
            string: None,
            start_length: Some(1),
            end_length: Some(1),
            variants: vec![part.to_string()],
            src: part.to_string(),
        }),
    }
}

pub fn parse_pattern(input_pattern: &str, dictionaries: &Dictionaries) -> Vec<Token> {
    split_keeping_delimiters(input_pattern)
        .into_iter()
        .filter(|p| !p.is_empty())
        .map(|p| part_to_token(&p, dictionaries))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_year_digits() {
        let parts = split_keeping_delimiters("Year 19##");
        assert_eq!(parts, vec!["Year 19", "#", "#"]);
    }
}
