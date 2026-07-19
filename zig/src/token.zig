const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TokenOptions = struct {
    string: ?[]const u8 = null,
    start_length: ?i32 = null,
    end_length: ?i32 = null,
    variants: []const []const u8,
    src: []const u8,
};

pub const Token = struct {
    src: []const u8,
    start_length: i32,
    end_length: i32,
    variants: []const []const u8,
    count: i32,

    fn defaultInteger(option: ?i32, fallback: i32) i32 {
        if (option) |v| {
            if (v >= 0) return v;
        }
        return fallback;
    }

    fn powInt(base: i32, exp: i32) i32 {
        var result: i32 = 1;
        var i: i32 = 0;
        while (i < exp) : (i += 1) {
            result *= base;
        }
        return result;
    }

    pub fn init(options: TokenOptions) Token {
        const start_length = defaultInteger(options.start_length, 1);
        const end_length = defaultInteger(options.end_length, 1);
        const variants = options.variants;
        var count: i32 = 0;
        var length = start_length;
        while (length <= end_length) : (length += 1) {
            count += powInt(@intCast(variants.len), length);
        }
        return .{
            .src = options.src,
            .start_length = start_length,
            .end_length = end_length,
            .variants = variants,
            .count = count,
        };
    }

    pub fn get(self: Token, allocator: Allocator, index: i32) ![]u8 {
        if (index > self.count - 1 or index < 0) {
            return try allocator.dupe(u8, "");
        }
        if (index == 0 and self.start_length == 0) {
            return try allocator.dupe(u8, "");
        }

        var index_with_offset = index;
        var string_length = self.start_length;
        var length = self.start_length;
        while (length <= self.end_length) : (length += 1) {
            const offset_count = powInt(@intCast(self.variants.len), length);
            if (index_with_offset < offset_count) {
                string_length = length;
                break;
            }
            index_with_offset -= offset_count;
        }

        var out = std.ArrayList(u8).init(allocator);
        errdefer out.deinit();
        var i: i32 = 0;
        while (i < string_length) : (i += 1) {
            const variant_index: usize = @intCast(@mod(index_with_offset, @as(i32, @intCast(self.variants.len))));
            index_with_offset = @divTrunc(index_with_offset, @as(i32, @intCast(self.variants.len)));
            try out.appendSlice(self.variants[variant_index]);
        }
        return try out.toOwnedSlice();
    }
};
