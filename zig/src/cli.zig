const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("json.zig");
const JsonValue = json.JsonValue;
const Dictionaries = @import("parse_pattern.zig").Dictionaries;
const Wildling = @import("wildling.zig").Wildling;
const VERSION = @import("wildling.zig").VERSION;
const Generator = @import("generator.zig").Generator;

const Range = struct { start: i32, end: i32 };

const CliArgs = struct {
    selects: std.ArrayList(i32),
    ranges: std.ArrayList(Range),
    check: bool = false,
    dictionaries: Dictionaries,
    patterns: std.ArrayList([]const u8),
    help: bool = false,
    version: bool = false,

    fn init(allocator: Allocator) CliArgs {
        return .{
            .selects = std.ArrayList(i32).init(allocator),
            .ranges = std.ArrayList(Range).init(allocator),
            .dictionaries = Dictionaries.init(allocator),
            .patterns = std.ArrayList([]const u8).init(allocator),
        };
    }
};

fn parseRange(value: []const u8) ?Range {
    const dash = std.mem.indexOfScalar(u8, value, '-') orelse return null;
    const left = value[0..dash];
    const right = value[dash + 1 ..];
    if (left.len == 0 or right.len == 0) return null;
    for (left) |c| if (c < '0' or c > '9') return null;
    for (right) |c| if (c < '0' or c > '9') return null;
    const start = std.fmt.parseInt(i32, left, 10) catch return null;
    const end = std.fmt.parseInt(i32, right, 10) catch return null;
    if (start <= end) return .{ .start = start, .end = end };
    return null;
}

fn loadDictionaryFile(allocator: Allocator, path: []const u8) !?[]const []const u8 {
    const content = std.fs.cwd().readFileAlloc(allocator, path, 16 * 1024 * 1024) catch return null;
    defer allocator.free(content);

    var words = std.ArrayList([]const u8).init(allocator);
    errdefer words.deinit();

    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try words.append(try allocator.dupe(u8, trimmed));
    }
    return try words.toOwnedSlice();
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

fn applyDictionary(allocator: Allocator, result: *CliArgs, name: []const u8, value: JsonValue) !void {
    switch (value) {
        .array => |items| {
            var words = std.ArrayList([]const u8).init(allocator);
            errdefer words.deinit();
            for (items) |item| {
                const s = switch (item) {
                    .string => |str| try allocator.dupe(u8, str),
                    .number => |n| try std.fmt.allocPrint(allocator, "{d}", .{@as(i64, @intFromFloat(n))}),
                    .bool => |b| try allocator.dupe(u8, if (b) "true" else "false"),
                    else => continue,
                };
                if (s.len == 0) {
                    allocator.free(s);
                    continue;
                }
                try words.append(s);
            }
            try result.dictionaries.put(try allocator.dupe(u8, name), try words.toOwnedSlice());
        },
        .string => |path| {
            if (pathExists(path)) {
                if (try loadDictionaryFile(allocator, path)) |words| {
                    try result.dictionaries.put(try allocator.dupe(u8, name), words);
                }
            }
        },
        else => {},
    }
}

fn applyDictionaryPath(allocator: Allocator, result: *CliArgs, name: []const u8, path: []const u8) !void {
    if (pathExists(path)) {
        if (try loadDictionaryFile(allocator, path)) |words| {
            try result.dictionaries.put(try allocator.dupe(u8, name), words);
        }
    }
}

fn applyTemplate(allocator: Allocator, result: *CliArgs, path: []const u8) !void {
    const raw = std.fs.cwd().readFileAlloc(allocator, path, 16 * 1024 * 1024) catch {
        std.debug.print("Template file not found: {s}\n", .{path});
        std.process.exit(1);
    };

    const root_val = json.parse(allocator, raw) catch {
        std.debug.print("Invalid JSON template: {s}\n", .{path});
        std.process.exit(1);
    };

    const root = switch (root_val) {
        .object => |obj| obj,
        else => {
            std.debug.print("Invalid JSON template: {s}\n", .{path});
            std.process.exit(1);
        },
    };

    if (root.get("check")) |check_val| {
        if (check_val == .bool and check_val.bool) {
            result.check = true;
        }
    }

    if (root.get("select")) |select_val| {
        if (select_val == .array) {
            for (select_val.array) |val| {
                const number: ?i32 = switch (val) {
                    .number => |n| @intFromFloat(n),
                    .string => |s| std.fmt.parseInt(i32, s, 10) catch null,
                    else => null,
                };
                if (number) |n| {
                    if (n >= 0) try result.selects.append(n);
                }
            }
        }
    }

    if (root.get("range")) |range_val| {
        if (range_val == .array) {
            for (range_val.array) |rv| {
                if (rv == .string) {
                    if (parseRange(rv.string)) |r| {
                        try result.ranges.append(r);
                    }
                }
            }
        }
    }

    if (root.get("dictionaries")) |dicts_val| {
        if (dicts_val == .object) {
            var it = dicts_val.object.iterator();
            while (it.next()) |entry| {
                try applyDictionary(allocator, result, entry.key_ptr.*, entry.value_ptr.*);
            }
        }
    }

    if (root.get("patterns")) |patterns_val| {
        if (patterns_val == .array) {
            for (patterns_val.array) |pattern| {
                if (pattern == .string) {
                    try result.patterns.append(try allocator.dupe(u8, pattern.string));
                }
            }
        }
    }
}

fn parseArgs(allocator: Allocator, args: []const []const u8) !CliArgs {
    var result = CliArgs.init(allocator);
    var i: usize = 0;
    while (i < args.len) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            result.help = true;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            result.version = true;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--check")) {
            result.check = true;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--select")) {
            i += 1;
            if (i >= args.len) break;
            if (std.fmt.parseInt(i32, args[i], 10)) |val| {
                if (val >= 0) try result.selects.append(val);
            } else |_| {}
            i += 1;
        } else if (std.mem.eql(u8, arg, "--range")) {
            i += 1;
            if (i >= args.len) break;
            if (parseRange(args[i])) |r| {
                try result.ranges.append(r);
            }
            i += 1;
        } else if (std.mem.eql(u8, arg, "--dictionary")) {
            i += 1;
            if (i >= args.len) break;
            if (std.mem.indexOfScalar(u8, args[i], ':')) |colon| {
                const name = args[i][0..colon];
                const path = args[i][colon + 1 ..];
                if (name.len > 0 and path.len > 0) {
                    try applyDictionaryPath(allocator, &result, name, path);
                }
            }
            i += 1;
        } else if (std.mem.eql(u8, arg, "--template")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Missing path for --template\n", .{});
                std.process.exit(1);
            }
            try applyTemplate(allocator, &result, args[i]);
            i += 1;
        } else {
            try result.patterns.append(try allocator.dupe(u8, arg));
            i += 1;
        }
    }
    return result;
}

fn loadHelpText(allocator: Allocator) ![]const u8 {
    var candidates = std.ArrayList([]const u8).init(allocator);
    defer candidates.deinit();

    if (std.fs.selfExeDirPathAlloc(allocator)) |dir| {
        defer allocator.free(dir);
        try candidates.append(try std.fs.path.join(allocator, &.{ dir, "help.txt" }));
        try candidates.append(try std.fs.path.join(allocator, &.{ dir, "..", "docs", "help.txt" }));
    } else |_| {}

    try candidates.append(try allocator.dupe(u8, "docs/help.txt"));

    for (candidates.items) |path| {
        if (std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024)) |content| {
            return content;
        } else |_| {}
    }

    return try allocator.dupe(u8, "wildling - pattern based string generator\n\nHelp text unavailable.\n");
}

fn formatList(allocator: Allocator, values: []const []const u8) ![]const u8 {
    if (values.len == 0) return try allocator.dupe(u8, "");
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    try out.append(' ');
    for (values, 0..) |v, idx| {
        if (idx > 0) try out.append(' ');
        try out.appendSlice(v);
    }
    return try out.toOwnedSlice();
}

fn formatCheckOutput(allocator: Allocator, args: *const CliArgs, total: i32, generators: []const Generator) ![]const u8 {
    var dict_names = std.ArrayList([]const u8).init(allocator);
    defer dict_names.deinit();
    var dit = args.dictionaries.keyIterator();
    while (dit.next()) |key| {
        try dict_names.append(key.*);
    }

    var selects = std.ArrayList([]const u8).init(allocator);
    defer {
        for (selects.items) |s| allocator.free(s);
        selects.deinit();
    }
    for (args.selects.items) |s| {
        try selects.append(try std.fmt.allocPrint(allocator, "{d}", .{s}));
    }

    var ranges = std.ArrayList([]const u8).init(allocator);
    defer {
        for (ranges.items) |r| allocator.free(r);
        ranges.deinit();
    }
    for (args.ranges.items) |r| {
        try ranges.append(try std.fmt.allocPrint(allocator, "{d}-{d}", .{ r.start, r.end }));
    }

    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    try lines.append(try std.fmt.allocPrint(allocator, "patterns:{s}", .{try formatList(allocator, args.patterns.items)}));
    try lines.append(try std.fmt.allocPrint(allocator, "dictionaries:{s}", .{try formatList(allocator, dict_names.items)}));
    try lines.append(try std.fmt.allocPrint(allocator, "select:{s}", .{try formatList(allocator, selects.items)}));
    try lines.append(try std.fmt.allocPrint(allocator, "range:{s}", .{try formatList(allocator, ranges.items)}));
    try lines.append(try std.fmt.allocPrint(allocator, "total: {d}", .{total}));
    for (generators) |gen| {
        try lines.append(try std.fmt.allocPrint(allocator, "generator: {s} {d}", .{ gen.source, gen.count }));
    }

    return try std.mem.join(allocator, "\n", lines.items);
}

pub fn runCli(allocator: Allocator, args: []const []const u8) !u8 {
    const parsed = try parseArgs(allocator, args);

    if (parsed.help) {
        const help = try loadHelpText(allocator);
        const trimmed = std.mem.trimRight(u8, help, " \t\r\n");
        try std.io.getStdOut().writer().print("{s}\n", .{trimmed});
        return 0;
    }

    if (parsed.version) {
        try std.io.getStdOut().writer().print("wildling {s}\n", .{VERSION});
        return 0;
    }

    if (parsed.patterns.items.len == 0) {
        try std.io.getStdErr().writer().writeAll("No pattern provided. Use --help for usage information.\n");
        return 1;
    }

    var wildcard = try Wildling.init(allocator, parsed.patterns.items, &parsed.dictionaries);
    const stdout = std.io.getStdOut().writer();

    if (parsed.check) {
        const out = try formatCheckOutput(allocator, &parsed, wildcard.count(), wildcard.generators);
        try stdout.print("{s}\n", .{out});
        return 0;
    }

    if (parsed.selects.items.len > 0 or parsed.ranges.items.len > 0) {
        for (parsed.selects.items) |idx| {
            if (try wildcard.get(allocator, idx)) |value| {
                try stdout.print("{s}\n", .{value});
            } else {
                try stdout.writeAll("false\n");
            }
        }
        for (parsed.ranges.items) |range| {
            var idx = range.start;
            while (idx <= range.end) : (idx += 1) {
                if (try wildcard.get(allocator, idx)) |value| {
                    try stdout.print("{s}\n", .{value});
                } else {
                    try stdout.writeAll("false\n");
                }
            }
        }
        return 0;
    }

    while (try wildcard.next(allocator)) |value| {
        try stdout.print("{s}\n", .{value});
    }
    return 0;
}
