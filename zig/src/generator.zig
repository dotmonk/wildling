const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const parse_pattern = @import("parse_pattern.zig");
const Dictionaries = parse_pattern.Dictionaries;

pub const Generator = struct {
    source: []const u8,
    tokens: []Token,
    count: i32,

    pub fn init(allocator: Allocator, input_pattern: []const u8, dictionaries: *const Dictionaries) !Generator {
        const tokens = try parse_pattern.parsePattern(allocator, input_pattern, dictionaries);
        var count: i32 = 1;
        for (tokens) |t| {
            count *= t.count;
        }
        return .{
            .source = try allocator.dupe(u8, input_pattern),
            .tokens = tokens,
            .count = count,
        };
    }

    pub fn get(self: Generator, allocator: Allocator, index: i32) ![]u8 {
        if (index > self.count - 1 or index < 0) {
            return try allocator.dupe(u8, "");
        }
        var out = std.ArrayList(u8).init(allocator);
        errdefer out.deinit();
        var index_with_offset = index;
        for (self.tokens) |t| {
            const piece = try t.get(allocator, @mod(index_with_offset, t.count));
            defer allocator.free(piece);
            try out.appendSlice(piece);
            index_with_offset = @divTrunc(index_with_offset, t.count);
        }
        return try out.toOwnedSlice();
    }
};
