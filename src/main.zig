const std = @import("std");
const fs = std.fs;
const process = std.process;
const heap = std.heap;
const GeneralPurposeAllocator = heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const equal = std.mem.eql;
const split = std.mem.split;
const parseInt = std.fmt.parseInt;
const Chameleon = @import("chameleon");
const SuperFile = @import("./super_file.zig").SuperFile;

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

    try print_header("list");

    const leds = try get_leds();

    for (leds) |led| {
        try c.green().printOut("{s}\n", .{led});
    }
}

fn get_args() ![][]u8 {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    errdefer _ = gpa.deinit();

    const args = try process.argsAlloc(allocator);
    errdefer process.argsFree(allocator, args);

    return args;
}

fn print_header(command: []const u8) !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });

    defer c.deinit();
    defer _ = gpa.deinit();

    std.debug.print("{s} {s}\n\n", .{ try c.black().bgGreen().fmt(" openwrt led night mode ", .{}), command });
}

fn print_help() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });

    defer c.deinit();
    defer _ = gpa.deinit();

    try print_header("help");

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

fn includes(buffer: []const u8, search: []const u8) bool {
    if (buffer.len < search.len) {
        return false;
    }

    if (search.len == 0) {
        return false;
    }

    for (buffer, 0..) |_, i| {
        const start = i;
        const end = i + search.len;

        if (end > buffer.len) {
            break;
        }

        const str = buffer[start..end];

        if (equal(u8, str, search)) {
            return true;
        }
    }

    return false;
}

fn strip_installation(content: []u8) ![][]const u8 {
    var lines = split(u8, content, "\n");
    var ignore = false;

    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    errdefer _ = gpa.deinit();

    var list = ArrayList([]const u8).init(allocator);
    errdefer list.deinit();

    while (lines.next()) |line| {
        if (includes(line, "#openwrt-led-night-mode-start\n")) {
            ignore = true;
        } else if (includes(line, "#openwrt-led-night-mode-end\n")) {
            ignore = false;
        } else if (!ignore) {
            try list.append(line);
        }
    }

    return list.toOwnedSlice();
}

fn uninstall() !void {
    try print_header("uninstall");
}

fn install(args: [][]u8) !void {
    try print_header("install");

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

    const commands = try build_commands(start_hour, start_minute, end_hour, end_minute);

    var superFile = try SuperFile.init("/var/spool/cron/crontabs/root");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const content = try superFile.read(allocator);
    const stripped = try strip_installation(content);

    try superFile.clear();

    for (stripped) |line| {
        _ = try superFile.file.write(line);
    }

    _ = try superFile.file.write(commands);
}

pub fn main() !void {
    const args = try get_args();
    const command = args[1];

    if (args.len == 1 or equal(u8, command, "help")) {
        try print_help();
    } else if (equal(u8, command, "list")) {
        try print_leds();
    } else if (equal(u8, command, "install")) {
        try install(args);
    } else if (equal(u8, command, "uninstall")) {
        try uninstall();
    }
}
