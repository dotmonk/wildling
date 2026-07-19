const std = @import("std");
const cli = @import("cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    var arg_list = std.ArrayList([]const u8).init(allocator);
    while (args.next()) |arg| {
        try arg_list.append(arg);
    }

    const code = try cli.runCli(allocator, arg_list.items);
    std.process.exit(code);
}
