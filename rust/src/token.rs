#[derive(Clone, Debug)]
pub struct TokenOptions {
    pub string: Option<String>,
    pub start_length: Option<i32>,
    pub end_length: Option<i32>,
    pub variants: Vec<String>,
    pub src: String,
}

#[derive(Clone, Debug)]
pub struct Token {
    src: String,
    start_length: i32,
    end_length: i32,
    variants: Vec<String>,
    count: i32,
}

fn default_integer(option: Option<i32>, fallback: i32) -> i32 {
    match option {
        Some(v) if v >= 0 => v,
        _ => fallback,
    }
}

fn pow_int(base: i32, exp: i32) -> i32 {
    let mut result = 1;
    for _ in 0..exp {
        result *= base;
    }
    result
}

impl Token {
    pub fn new(options: TokenOptions) -> Self {
        let start_length = default_integer(options.start_length, 1);
        let end_length = default_integer(options.end_length, 1);
        let variants = options.variants;
        let mut count = 0;
        let mut length = start_length;
        while length <= end_length {
            count += pow_int(variants.len() as i32, length);
            length += 1;
        }
        Self {
            src: options.src,
            start_length,
            end_length,
            variants,
            count,
        }
    }

    pub fn count(&self) -> i32 {
        self.count
    }

    pub fn src(&self) -> &str {
        &self.src
    }

    pub fn get(&self, index: i32) -> String {
        if index > self.count - 1 || index < 0 {
            return String::new();
        }
        if index == 0 && self.start_length == 0 {
            return String::new();
        }

        let mut index_with_offset = index;
        let mut string_length = self.start_length;
        let mut length = self.start_length;
        while length <= self.end_length {
            let offset_count = pow_int(self.variants.len() as i32, length);
            if index_with_offset < offset_count {
                string_length = length;
                break;
            }
            index_with_offset -= offset_count;
            length += 1;
        }

        let mut out = String::new();
        for _ in 0..string_length {
            let variant_index = (index_with_offset as usize) % self.variants.len();
            index_with_offset /= self.variants.len() as i32;
            out.push_str(&self.variants[variant_index]);
        }
        out
    }
}
