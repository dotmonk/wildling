const std = @import("std");
const Allocator = std.mem.Allocator;

pub const JsonValue = union(enum) {
    null,
    bool: bool,
    number: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringArrayHashMap(JsonValue),
};

pub const Parser = struct {
    text: []const u8,
    pos: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, text: []const u8) Parser {
        return .{
            .text = text,
            .pos = 0,
            .allocator = allocator,
        };
    }

    fn skipWs(self: *Parser) void {
        while (self.pos < self.text.len) {
            switch (self.text[self.pos]) {
                ' ', '\n', '\r', '\t' => self.pos += 1,
                else => break,
            }
        }
    }

    fn peek(self: *Parser, expected: u8) bool {
        return self.pos < self.text.len and self.text[self.pos] == expected;
    }

    fn expect(self: *Parser, expected: u8) !void {
        self.skipWs();
        if (!self.peek(expected)) return error.ExpectedChar;
        self.pos += 1;
    }

    pub fn parseValue(self: *Parser) anyerror!JsonValue {
        self.skipWs();
        if (self.pos >= self.text.len) return error.UnexpectedEnd;
        return switch (self.text[self.pos]) {
            '{' => try self.parseObject(),
            '[' => try self.parseArray(),
            '"' => .{ .string = try self.parseString() },
            't', 'f' => .{ .bool = try self.parseBool() },
            'n' => blk: {
                try self.parseNull();
                break :blk .null;
            },
            '-', '0'...'9' => .{ .number = try self.parseNumber() },
            else => error.UnexpectedCharacter,
        };
    }

    fn parseObject(self: *Parser) anyerror!JsonValue {
        try self.expect('{');
        var object = std.StringArrayHashMap(JsonValue).init(self.allocator);
        errdefer object.deinit();

        self.skipWs();
        if (self.peek('}')) {
            self.pos += 1;
            return .{ .object = object };
        }

        while (true) {
            self.skipWs();
            const key = try self.parseString();
            self.skipWs();
            try self.expect(':');
            const value = try self.parseValue();
            try object.put(key, value);
            self.skipWs();
            if (self.peek('}')) {
                self.pos += 1;
                return .{ .object = object };
            }
            try self.expect(',');
        }
    }

    fn parseArray(self: *Parser) anyerror!JsonValue {
        try self.expect('[');
        var array = std.ArrayList(JsonValue).init(self.allocator);
        errdefer array.deinit();

        self.skipWs();
        if (self.peek(']')) {
            self.pos += 1;
            return .{ .array = try array.toOwnedSlice() };
        }

        while (true) {
            try array.append(try self.parseValue());
            self.skipWs();
            if (self.peek(']')) {
                self.pos += 1;
                return .{ .array = try array.toOwnedSlice() };
            }
            try self.expect(',');
        }
    }

    fn parseString(self: *Parser) ![]const u8 {
        try self.expect('"');
        var out = std.ArrayList(u8).init(self.allocator);
        errdefer out.deinit();

        while (self.pos < self.text.len) {
            const c = self.text[self.pos];
            self.pos += 1;
            if (c == '"') {
                return try out.toOwnedSlice();
            }
            if (c == '\\') {
                if (self.pos >= self.text.len) return error.UnterminatedEscape;
                const esc = self.text[self.pos];
                self.pos += 1;
                switch (esc) {
                    '"', '\\', '/' => try out.append(esc),
                    'b' => try out.append(0x08),
                    'f' => try out.append(0x0c),
                    'n' => try out.append('\n'),
                    'r' => try out.append('\r'),
                    't' => try out.append('\t'),
                    'u' => {
                        if (self.pos + 4 > self.text.len) return error.InvalidUnicodeEscape;
                        const hex = self.text[self.pos .. self.pos + 4];
                        const code = try std.fmt.parseInt(u21, hex, 16);
                        var buf: [4]u8 = undefined;
                        const len = try std.unicode.utf8Encode(code, &buf);
                        try out.appendSlice(buf[0..len]);
                        self.pos += 4;
                    },
                    else => return error.InvalidEscape,
                }
            } else {
                try out.append(c);
            }
        }
        return error.UnterminatedString;
    }

    fn parseNumber(self: *Parser) !f64 {
        const start = self.pos;
        if (self.peek('-')) self.pos += 1;
        while (self.pos < self.text.len and self.text[self.pos] >= '0' and self.text[self.pos] <= '9') {
            self.pos += 1;
        }
        if (self.peek('.')) {
            self.pos += 1;
            while (self.pos < self.text.len and self.text[self.pos] >= '0' and self.text[self.pos] <= '9') {
                self.pos += 1;
            }
        }
        if (self.pos < self.text.len and (self.text[self.pos] == 'e' or self.text[self.pos] == 'E')) {
            self.pos += 1;
            if (self.peek('+') or self.peek('-')) self.pos += 1;
            while (self.pos < self.text.len and self.text[self.pos] >= '0' and self.text[self.pos] <= '9') {
                self.pos += 1;
            }
        }
        return try std.fmt.parseFloat(f64, self.text[start..self.pos]);
    }

    fn parseBool(self: *Parser) !bool {
        if (std.mem.startsWith(u8, self.text[self.pos..], "true")) {
            self.pos += 4;
            return true;
        }
        if (std.mem.startsWith(u8, self.text[self.pos..], "false")) {
            self.pos += 5;
            return false;
        }
        return error.InvalidBoolean;
    }

    fn parseNull(self: *Parser) !void {
        if (std.mem.startsWith(u8, self.text[self.pos..], "null")) {
            self.pos += 4;
            return;
        }
        return error.InvalidNull;
    }

    pub fn finish(self: *Parser) !void {
        self.skipWs();
        if (self.pos != self.text.len) return error.TrailingContent;
    }
};

pub fn parse(allocator: Allocator, text: []const u8) !JsonValue {
    var parser = Parser.init(allocator, text);
    const value = try parser.parseValue();
    try parser.finish();
    return value;
}
