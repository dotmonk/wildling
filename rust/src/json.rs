use std::collections::BTreeMap;

#[derive(Clone, Debug)]
pub enum JsonValue {
    Null,
    Bool(bool),
    Number(f64),
    String(String),
    Array(Vec<JsonValue>),
    Object(BTreeMap<String, JsonValue>),
}

pub struct Parser<'a> {
    text: &'a str,
    pos: usize,
}

impl<'a> Parser<'a> {
    pub fn new(text: &'a str) -> Self {
        Self { text, pos: 0 }
    }

    fn skip_ws(&mut self) {
        while let Some(c) = self.text[self.pos..].chars().next() {
            if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
                self.pos += c.len_utf8();
            } else {
                break;
            }
        }
    }

    fn peek(&self, expected: char) -> bool {
        self.text[self.pos..].starts_with(expected)
    }

    fn expect(&mut self, expected: char) -> Result<(), String> {
        self.skip_ws();
        if !self.peek(expected) {
            return Err(format!("Expected '{expected}'"));
        }
        self.pos += expected.len_utf8();
        Ok(())
    }

    pub fn parse_value(&mut self) -> Result<JsonValue, String> {
        self.skip_ws();
        let c = self
            .text
            .chars()
            .nth(self.pos)
            .ok_or_else(|| "Unexpected end of JSON".to_string())?;
        match c {
            '{' => self.parse_object(),
            '[' => self.parse_array(),
            '"' => Ok(JsonValue::String(self.parse_string()?)),
            't' | 'f' => Ok(JsonValue::Bool(self.parse_bool()?)),
            'n' => {
                self.parse_null()?;
                Ok(JsonValue::Null)
            }
            '-' | '0'..='9' => Ok(JsonValue::Number(self.parse_number()?)),
            _ => Err("Unexpected character in JSON".to_string()),
        }
    }

    fn parse_object(&mut self) -> Result<JsonValue, String> {
        self.expect('{')?;
        let mut object = BTreeMap::new();
        self.skip_ws();
        if self.peek('}') {
            self.pos += 1;
            return Ok(JsonValue::Object(object));
        }
        loop {
            self.skip_ws();
            let key = self.parse_string()?;
            self.skip_ws();
            self.expect(':')?;
            let value = self.parse_value()?;
            object.insert(key, value);
            self.skip_ws();
            if self.peek('}') {
                self.pos += 1;
                return Ok(JsonValue::Object(object));
            }
            self.expect(',')?;
        }
    }

    fn parse_array(&mut self) -> Result<JsonValue, String> {
        self.expect('[')?;
        let mut array = Vec::new();
        self.skip_ws();
        if self.peek(']') {
            self.pos += 1;
            return Ok(JsonValue::Array(array));
        }
        loop {
            array.push(self.parse_value()?);
            self.skip_ws();
            if self.peek(']') {
                self.pos += 1;
                return Ok(JsonValue::Array(array));
            }
            self.expect(',')?;
        }
    }

    fn parse_string(&mut self) -> Result<String, String> {
        self.expect('"')?;
        let mut out = String::new();
        while self.pos < self.text.len() {
            let c = self.text[self.pos..].chars().next().unwrap();
            self.pos += c.len_utf8();
            if c == '"' {
                return Ok(out);
            }
            if c == '\\' {
                let esc = self
                    .text
                    .chars()
                    .nth(self.pos)
                    .ok_or_else(|| "Unterminated escape".to_string())?;
                self.pos += esc.len_utf8();
                match esc {
                    '"' | '\\' | '/' => out.push(esc),
                    'b' => out.push('\u{0008}'),
                    'f' => out.push('\u{000c}'),
                    'n' => out.push('\n'),
                    'r' => out.push('\r'),
                    't' => out.push('\t'),
                    'u' => {
                        if self.pos + 4 > self.text.len() {
                            return Err("Invalid unicode escape".to_string());
                        }
                        let hex = &self.text[self.pos..self.pos + 4];
                        let code = u32::from_str_radix(hex, 16)
                            .map_err(|_| "Invalid unicode escape".to_string())?;
                        out.push(char::from_u32(code).unwrap_or('\u{fffd}'));
                        self.pos += 4;
                    }
                    _ => return Err("Invalid escape".to_string()),
                }
            } else {
                out.push(c);
            }
        }
        Err("Unterminated string".to_string())
    }

    fn parse_number(&mut self) -> Result<f64, String> {
        let start = self.pos;
        if self.peek('-') {
            self.pos += 1;
        }
        while self
            .text
            .chars()
            .nth(self.pos)
            .map(|c| c.is_ascii_digit())
            .unwrap_or(false)
        {
            self.pos += 1;
        }
        if self.peek('.') {
            self.pos += 1;
            while self
                .text
                .chars()
                .nth(self.pos)
                .map(|c| c.is_ascii_digit())
                .unwrap_or(false)
            {
                self.pos += 1;
            }
        }
        if matches!(self.text.chars().nth(self.pos), Some('e' | 'E')) {
            self.pos += 1;
            if self.peek('+') || self.peek('-') {
                self.pos += 1;
            }
            while self
                .text
                .chars()
                .nth(self.pos)
                .map(|c| c.is_ascii_digit())
                .unwrap_or(false)
            {
                self.pos += 1;
            }
        }
        self.text[start..self.pos]
            .parse()
            .map_err(|_| "Invalid number".to_string())
    }

    fn parse_bool(&mut self) -> Result<bool, String> {
        if self.text[self.pos..].starts_with("true") {
            self.pos += 4;
            Ok(true)
        } else if self.text[self.pos..].starts_with("false") {
            self.pos += 5;
            Ok(false)
        } else {
            Err("Invalid boolean".to_string())
        }
    }

    fn parse_null(&mut self) -> Result<(), String> {
        if self.text[self.pos..].starts_with("null") {
            self.pos += 4;
            Ok(())
        } else {
            Err("Invalid null".to_string())
        }
    }

    pub fn finish(&mut self) -> Result<(), String> {
        self.skip_ws();
        if self.pos != self.text.len() {
            Err("Unexpected trailing JSON content".to_string())
        } else {
            Ok(())
        }
    }
}

pub fn parse(text: &str) -> Result<JsonValue, String> {
    let mut parser = Parser::new(text);
    let value = parser.parse_value()?;
    parser.finish()?;
    Ok(value)
}
