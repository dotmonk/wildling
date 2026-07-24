const std = @import("std");
const Allocator = std.mem.Allocator;
const Generator = @import("generator.zig").Generator;
const Dictionaries = @import("parse_pattern.zig").Dictionaries;

pub const VERSION = "2.0.5";

pub const Wildling = struct {
    generators: []Generator,
    pattern_count: i32,
    internal_index: i32,

    pub fn init(allocator: Allocator, patterns: []const []const u8, dictionaries: *const Dictionaries) !Wildling {
        var generators = try allocator.alloc(Generator, patterns.len);
        errdefer allocator.free(generators);

        var total: i32 = 0;
        for (patterns, 0..) |pattern, i| {
            generators[i] = try Generator.init(allocator, pattern, dictionaries);
            total += generators[i].count;
        }

        return .{
            .generators = generators,
            .pattern_count = total,
            .internal_index = 0,
        };
    }

    pub fn index(self: Wildling) i32 {
        return self.internal_index;
    }

    pub fn count(self: Wildling) i32 {
        return self.pattern_count;
    }

    pub fn reset(self: *Wildling) void {
        self.internal_index = 0;
    }

    pub fn next(self: *Wildling, allocator: Allocator) !?[]u8 {
        if (self.internal_index == self.pattern_count) {
            return null;
        }
        self.internal_index += 1;
        return try self.get(allocator, self.internal_index - 1);
    }

    pub fn get(self: Wildling, allocator: Allocator, idx: i32) !?[]u8 {
        if (idx > self.pattern_count - 1 or idx < 0) {
            return null;
        }
        var segment_index: i32 = 0;
        for (self.generators) |generator| {
            const pattern_index = idx - segment_index;
            if (pattern_index < generator.count) {
                return try generator.get(allocator, pattern_index);
            }
            segment_index += generator.count;
        }
        return null;
    }
};
