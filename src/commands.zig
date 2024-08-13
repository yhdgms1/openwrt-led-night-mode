const std = @import("std");
const process = std.process;
const mem = std.mem;
const equal = mem.eql;
const heap = std.heap;
const Chameleon = @import("chameleon");
const utils = @import("./utils.zig");

pub fn list() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });
    defer c.deinit();

    try utils.print_header("list");

    const leds = try utils.get_leds();

    for (leds) |led| {
        try c.green().printOut("{s}\n", .{led});
    }
}

pub fn help() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });
    defer c.deinit();

    try utils.print_header("help");

    const text =
        \\{s}      — print this message
        \\{s}      — print all LED's
        \\{s}   — install, configure via --start=22:00 and --end=07:00 flags
        \\{s} — uninstall
        \\
    ;

    std.debug.print(text, .{
        try c.magentaBright().fmt("help", .{}),
        try c.magentaBright().fmt("list", .{}),
        try c.magentaBright().fmt("install", .{}),
        try c.magentaBright().fmt("uninstall", .{}),
    });
}

pub fn install(args: [][]u8) !void {
    try utils.print_header("install");

    const commands = try utils.build_commands(try utils.parse_args(args));

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var cronFile = try utils.get_cron_file_stripped(allocator);

    _ = try cronFile.file.write(commands);

    defer cronFile.deinit();

    try utils.apply_cron_changes();
}

pub fn uninstall() !void {
    try utils.print_header("uninstall");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var cronFile = try utils.get_cron_file_stripped(allocator);

    defer cronFile.deinit();

    try utils.apply_cron_changes();
}
