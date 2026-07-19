const std = @import("std");
const Allocator = std.mem.Allocator;
const token_mod = @import("token.zig");
const Token = token_mod.Token;
const TokenOptions = token_mod.TokenOptions;

pub const Dictionaries = std.StringHashMap([]const []const u8);

fn isSpecial(c: u8) bool {
    return switch (c) {
        '#', '@', '$', '*', '&', '?', '!', '-', '%' => true,
        else => false,
    };
}

fn splitKeepingDelimiters(allocator: Allocator, input: []const u8) ![][]const u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    errdefer parts.deinit();

    var i: usize = 0;
    var literal_start: usize = 0;

    while (i < input.len) {
        if (input[i] == '\\' and i + 1 < input.len and isSpecial(input[i + 1])) {
            if (i > literal_start) {
                try parts.append(try allocator.dupe(u8, input[literal_start..i]));
            }
            try parts.append(try allocator.dupe(u8, input[i .. i + 2]));
            i += 2;
            literal_start = i;
            continue;
        }

        if (isSpecial(input[i]) and i + 1 < input.len and input[i + 1] == '{') {
            if (i > literal_start) {
                try parts.append(try allocator.dupe(u8, input[literal_start..i]));
            }
            var j = i + 2;
            while (j < input.len and input[j] != '}') : (j += 1) {}
            if (j < input.len and input[j] == '}') {
                try parts.append(try allocator.dupe(u8, input[i .. j + 1]));
                i = j + 1;
                literal_start = i;
                continue;
            }
        }

        if (isSpecial(input[i])) {
            if (i > literal_start) {
                try parts.append(try allocator.dupe(u8, input[literal_start..i]));
            }
            try parts.append(try allocator.dupe(u8, input[i .. i + 1]));
            i += 1;
            literal_start = i;
            continue;
        }

        i += 1;
    }

    if (literal_start < input.len) {
        try parts.append(try allocator.dupe(u8, input[literal_start..]));
    }

    return try parts.toOwnedSlice();
}

fn parseLengthWithVariants(allocator: Allocator, part: []const u8, variants: []const []const u8) !TokenOptions {
    var start_length: i32 = 1;
    var end_length: i32 = 1;

    if (std.mem.indexOfScalar(u8, part, '{')) |open| {
        if (std.mem.indexOfScalar(u8, part[open..], '}')) |rel_close| {
            const inner = part[open + 1 .. open + rel_close];
            if (std.mem.indexOfScalar(u8, inner, '-')) |dash| {
                const s = std.fmt.parseInt(i32, inner[0..dash], 10) catch null;
                const e = std.fmt.parseInt(i32, inner[dash + 1 ..], 10) catch null;
                if (s != null and e != null) {
                    start_length = s.?;
                    end_length = e.?;
                }
            } else if (std.fmt.parseInt(i32, inner, 10)) |n| {
                start_length = n;
                end_length = n;
            } else |_| {}
        }
    }

    return .{
        .string = null,
        .start_length = start_length,
        .end_length = end_length,
        .variants = variants,
        .src = try allocator.dupe(u8, part),
    };
}

const ParsedStringLength = struct {
    content: []const u8,
    start_length: i32,
    end_length: i32,
};

fn parseLengthWithString(part: []const u8) ?ParsedStringLength {
    const open = std.mem.indexOf(u8, part, "{'") orelse return null;
    const after_open = open + 2;
    if (after_open > part.len) return null;
    const rest = part[after_open..];
    const close_quote = std.mem.lastIndexOfScalar(u8, rest, '\'') orelse return null;
    const content = rest[0..close_quote];
    const after_quote = rest[close_quote + 1 ..];

    if (!std.mem.startsWith(u8, after_quote, "}") and !std.mem.startsWith(u8, after_quote, ",")) {
        if (std.mem.indexOfScalar(u8, after_quote, '}') == null) return null;
    }

    var start_length: i32 = 1;
    var end_length: i32 = 1;

    if (std.mem.startsWith(u8, after_quote, ",")) {
        var before_brace = after_quote[1..];
        if (std.mem.endsWith(u8, before_brace, "}")) {
            before_brace = before_brace[0 .. before_brace.len - 1];
        }
        if (std.mem.indexOfScalar(u8, before_brace, '-')) |dash| {
            const s = std.fmt.parseInt(i32, before_brace[0..dash], 10) catch null;
            const e = std.fmt.parseInt(i32, before_brace[dash + 1 ..], 10) catch null;
            if (s != null and e != null) {
                start_length = s.?;
                end_length = e.?;
            }
        } else if (std.fmt.parseInt(i32, before_brace, 10)) |n| {
            start_length = n;
            end_length = n;
        } else |_| {}
    } else if (!std.mem.startsWith(u8, after_quote, "}")) {
        return null;
    }

    return .{
        .content = content,
        .start_length = start_length,
        .end_length = end_length,
    };
}

fn charsAsVariants(allocator: Allocator, s: []const u8) ![]const []const u8 {
    var variants = try allocator.alloc([]const u8, s.len);
    for (s, 0..) |c, idx| {
        const one = try allocator.alloc(u8, 1);
        one[0] = c;
        variants[idx] = one;
    }
    return variants;
}

fn simpleTokenizer(allocator: Allocator, part: []const u8, alphabet: []const u8) !Token {
    const variants = try charsAsVariants(allocator, alphabet);
    return Token.init(try parseLengthWithVariants(allocator, part, variants));
}

fn dictionaryTokenizer(allocator: Allocator, part: []const u8, dictionaries: *const Dictionaries) !Token {
    if (parseLengthWithString(part)) |parsed| {
        if (parsed.content.len == 0 or dictionaries.contains(parsed.content)) {
            const variants = if (dictionaries.get(parsed.content)) |v| v else &[_][]const u8{};
            return Token.init(.{
                .string = parsed.content,
                .start_length = parsed.start_length,
                .end_length = parsed.end_length,
                .variants = variants,
                .src = try allocator.dupe(u8, part),
            });
        }
    }
    const variants = try allocator.alloc([]const u8, 1);
    variants[0] = try allocator.dupe(u8, part);
    return Token.init(.{
        .string = null,
        .start_length = 1,
        .end_length = 1,
        .variants = variants,
        .src = try allocator.dupe(u8, part),
    });
}

fn wordsTokenizer(allocator: Allocator, part: []const u8) !Token {
    const parsed = parseLengthWithString(part) orelse {
        const variants = try allocator.alloc([]const u8, 1);
        variants[0] = try allocator.dupe(u8, part);
        return Token.init(.{
            .string = null,
            .start_length = 1,
            .end_length = 1,
            .variants = variants,
            .src = try allocator.dupe(u8, part),
        });
    };

    var variants_list = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (variants_list.items) |v| allocator.free(v);
        variants_list.deinit();
    }

    var work_owned = try allocator.dupe(u8, parsed.content);
    var work_string: []u8 = work_owned;
    var index: usize = 0;
    while (index < work_string.len) {
        if (index + 1 < work_string.len and work_string[index] == '\\' and work_string[index + 1] == ',') {
            index += 2;
        } else if (work_string[index] == ',') {
            try variants_list.append(try allocator.dupe(u8, work_string[0..index]));
            const rest = try allocator.dupe(u8, work_string[index + 1 ..]);
            allocator.free(work_owned);
            work_owned = rest;
            work_string = work_owned;
            index = 0;
        } else {
            index += 1;
        }
    }
    try variants_list.append(try allocator.dupe(u8, work_string));
    allocator.free(work_owned);
    for (variants_list.items) |*v| {
        var cleaned = std.ArrayList(u8).init(allocator);
        errdefer cleaned.deinit();
        var i: usize = 0;
        while (i < v.*.len) {
            if (i + 1 < v.*.len and v.*[i] == '\\' and v.*[i + 1] == ',') {
                try cleaned.append(',');
                i += 2;
            } else {
                try cleaned.append(v.*[i]);
                i += 1;
            }
        }
        allocator.free(v.*);
        v.* = try cleaned.toOwnedSlice();
    }

    return Token.init(.{
        .string = parsed.content,
        .start_length = parsed.start_length,
        .end_length = parsed.end_length,
        .variants = try variants_list.toOwnedSlice(),
        .src = try allocator.dupe(u8, part),
    });
}

fn partToToken(allocator: Allocator, part: []const u8, dictionaries: *const Dictionaries) !Token {
    if (part.len == 0) {
        const variants = try allocator.alloc([]const u8, 1);
        variants[0] = try allocator.dupe(u8, part);
        return Token.init(.{
            .string = null,
            .start_length = 1,
            .end_length = 1,
            .variants = variants,
            .src = try allocator.dupe(u8, part),
        });
    }

    return switch (part[0]) {
        '#' => try simpleTokenizer(allocator, part, "0123456789"),
        '@' => try simpleTokenizer(allocator, part, "abcdefghijklmnopqrstuvwxyz"),
        '*' => try simpleTokenizer(allocator, part, "abcdefghijklmnopqrstuvwxyz0123456789"),
        '-' => try simpleTokenizer(allocator, part, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
        '!' => try simpleTokenizer(allocator, part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        '?' => try simpleTokenizer(allocator, part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
        '&' => try simpleTokenizer(allocator, part, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        '%' => try dictionaryTokenizer(allocator, part, dictionaries),
        '$' => try wordsTokenizer(allocator, part),
        '\\' => blk: {
            if (part.len > 1 and isSpecial(part[1])) {
                const variants = try allocator.alloc([]const u8, 1);
                variants[0] = try allocator.dupe(u8, part[1..]);
                break :blk Token.init(.{
                    .string = null,
                    .start_length = 1,
                    .end_length = 1,
                    .variants = variants,
                    .src = try allocator.dupe(u8, part),
                });
            }
            const variants = try allocator.alloc([]const u8, 1);
            variants[0] = try allocator.dupe(u8, part);
            break :blk Token.init(.{
                .string = null,
                .start_length = 1,
                .end_length = 1,
                .variants = variants,
                .src = try allocator.dupe(u8, part),
            });
        },
        else => blk: {
            const variants = try allocator.alloc([]const u8, 1);
            variants[0] = try allocator.dupe(u8, part);
            break :blk Token.init(.{
                .string = null,
                .start_length = 1,
                .end_length = 1,
                .variants = variants,
                .src = try allocator.dupe(u8, part),
            });
        },
    };
}

pub fn parsePattern(allocator: Allocator, input_pattern: []const u8, dictionaries: *const Dictionaries) ![]Token {
    const parts = try splitKeepingDelimiters(allocator, input_pattern);
    defer {
        for (parts) |p| allocator.free(p);
        allocator.free(parts);
    }

    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    for (parts) |part| {
        if (part.len == 0) continue;
        try tokens.append(try partToToken(allocator, part, dictionaries));
    }

    return try tokens.toOwnedSlice();
}
