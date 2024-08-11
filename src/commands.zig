const std = @import("std");
const mem = std.mem;
const equal = mem.eql;
const split = mem.split;
const parseInt = std.fmt.parseInt;
const heap = std.heap;
const Chameleon = @import("chameleon");
const utils = @import("./utils.zig");

pub fn list() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });

    defer c.deinit();
    defer _ = gpa.deinit();

    try utils.print_header("list");

    const leds = try utils.get_leds();

    for (leds) |led| {
        try c.green().printOut("{s}\n", .{led});
    }
}

pub fn help() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });

    defer c.deinit();
    defer _ = gpa.deinit();

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

    var start_hour: u8 = 22;
    var start_minute: u8 = 0;
    var end_hour: u8 = 7;
    var end_minute: u8 = 0;

    var i: u4 = 2;

    while (i < args.len) : (i += 1) {
        const parameter = args[i];

        var parsed = split(u8, parameter, "=");

        const name = parsed.first()[2..];
        const value = parsed.next().?;

        var time = split(u8, value, ":");

        const hours_string = time.first();
        const minutes_string = time.next().?;

        const hours = try parseInt(u8, hours_string, 10);
        const minutes = try parseInt(u8, minutes_string, 10);

        if (equal(u8, name, "start")) {
            start_hour = hours;
            start_minute = minutes;
        } else if (equal(u8, name, "end")) {
            end_hour = hours;
            end_minute = minutes;
        }
    }

    const commands = try utils.build_commands(start_hour, start_minute, end_hour, end_minute);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer _ = gpa.deinit();

    var cronFile = try utils.get_cron_file_stripped(allocator);

    _ = try cronFile.file.write(commands);

    defer cronFile.deinit();
}

pub fn uninstall() !void {
    try utils.print_header("uninstall");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer _ = gpa.deinit();

    var cronFile = try utils.get_cron_file_stripped(allocator);

    defer cronFile.deinit();
}
