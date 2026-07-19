use crate::generator::Generator;
use crate::parse_pattern::Dictionaries;

pub const VERSION: &str = "1.0.0";

pub struct Wildling {
    generators: Vec<Generator>,
    pattern_count: i32,
    internal_index: i32,
}

impl Wildling {
    pub fn new(patterns: &[String], dictionaries: &Dictionaries) -> Self {
        let mut generators = Vec::new();
        let mut total = 0;
        for pattern in patterns {
            let gen = Generator::new(pattern, dictionaries);
            total += gen.count();
            generators.push(gen);
        }
        Self {
            generators,
            pattern_count: total,
            internal_index: 0,
        }
    }

    pub fn index(&self) -> i32 {
        self.internal_index
    }

    pub fn count(&self) -> i32 {
        self.pattern_count
    }

    pub fn reset(&mut self) {
        self.internal_index = 0;
    }

    pub fn next(&mut self) -> Option<String> {
        if self.internal_index == self.pattern_count {
            return None;
        }
        self.internal_index += 1;
        self.get(self.internal_index - 1)
    }

    pub fn generators(&self) -> &[Generator] {
        &self.generators
    }

    pub fn get(&self, index: i32) -> Option<String> {
        if index > self.pattern_count - 1 || index < 0 {
            return None;
        }
        let mut segment_index = 0;
        for generator in &self.generators {
            let pattern_index = index - segment_index;
            if pattern_index < generator.count() {
                return Some(generator.get(pattern_index));
            }
            segment_index += generator.count();
        }
        None
    }
}
