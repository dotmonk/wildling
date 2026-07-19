use crate::parse_pattern::{parse_pattern, Dictionaries};
use crate::token::Token;

#[derive(Clone, Debug)]
pub struct Generator {
    pub source: String,
    tokens: Vec<Token>,
    count: i32,
}

impl Generator {
    pub fn new(input_pattern: &str, dictionaries: &Dictionaries) -> Self {
        let tokens = parse_pattern(input_pattern, dictionaries);
        let mut count = 1;
        for token in &tokens {
            count *= token.count();
        }
        Self {
            source: input_pattern.to_string(),
            tokens,
            count,
        }
    }

    pub fn count(&self) -> i32 {
        self.count
    }

    pub fn tokens(&self) -> &[Token] {
        &self.tokens
    }

    pub fn get(&self, index: i32) -> String {
        if index > self.count - 1 || index < 0 {
            return String::new();
        }
        let mut out = String::new();
        let mut index_with_offset = index;
        for token in &self.tokens {
            out.push_str(&token.get(index_with_offset % token.count()));
            index_with_offset /= token.count();
        }
        out
    }
}
