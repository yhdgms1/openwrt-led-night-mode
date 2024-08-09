const std = @import("std");
const fs = std.fs;
const process = std.process;
const heap = std.heap;
const GeneralPurposeAllocator = heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const equal = std.mem.eql;
const Chameleon = @import("chameleon");

fn get_crontab_file_location() []u8 {
    return "/var/spool/cron/crontabs/root";
}

fn get_leds() ![][]const u8 {
    var dir = try fs.openDirAbsolute("/sys/class/leds/", .{ .iterate = true });
    defer dir.close();

    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    errdefer _ = gpa.deinit();

    var list = ArrayList([]const u8).init(allocator);
    errdefer list.deinit();

    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        // LEDs are stored as a symbolic links
        if (entry.kind == .sym_link) {
            try list.append(entry.name);
        }
    }

    return try list.toOwnedSlice();
}

fn print_leds() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });

    defer c.deinit();
    defer _ = gpa.deinit();

    const leds = try get_leds();

    for (leds) |led| {
        try c.green().printOut("{s}\n", .{led});
    }
}

fn uninstall() !void {}

fn get_args() ![][]u8 {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    errdefer _ = gpa.deinit();

    const args = try process.argsAlloc(allocator);
    errdefer process.argsFree(allocator, args);

    return args;
}

fn print_help() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });

    defer c.deinit();
    defer _ = gpa.deinit();

    const text =
        \\{s} help
        \\
        \\{s}      — print this message
        \\{s}      — print all LED's
        \\{s}   — install, configure via --start=22:00 and --end=07:00 flags
        \\{s} — uninstall
        \\
    ;

    std.debug.print(text, .{
        try c.black().bgGreen().fmt(" openwrt led night mode ", .{}),
        try c.magentaBright().fmt("help", .{}),
        try c.magentaBright().fmt("list", .{}),
        try c.magentaBright().fmt("install", .{}),
        try c.magentaBright().fmt("uninstall", .{}),
    });
}

fn build_commands(start_hour: u8, start_minute: u8, end_hour: u8, end_minute: u8) ![]u8 {
    const leds = try get_leds();

    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    errdefer _ = gpa.deinit();

    var list = ArrayList(u8).init(allocator);
    errdefer list.deinit();

    try list.writer().print("#openwrt-led-night-mode-start\n", .{});

    for (leds) |led| {
        try list.writer().print("{d} {d} * * * echo 0 > /sys/class/leds/{s}/brightness\n", .{ start_minute, start_hour, led });
        try list.writer().print("{d} {d} * * * echo 1 > /sys/class/leds/{s}/brightness\n", .{ end_minute, end_hour, led });
    }

    try list.writer().print("#openwrt-led-night-mode-end\n", .{});

    return list.toOwnedSlice();
}

pub fn main() !void {
    const args = try get_args();
    const command = args[1];

    if (args.len == 1 or equal(u8, command, "help")) {
        try print_help();
    } else if (equal(u8, command, "list")) {
        try print_leds();
    } else if (equal(u8, command, "install")) {
        const commands = try build_commands(22, 0, 7, 0);

        std.debug.print("{s}", .{commands});
    } else if (equal(u8, command, "uninstall")) {}
}
