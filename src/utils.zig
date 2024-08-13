const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const equal = mem.eql;
const splitSequence = mem.splitSequence;
const parseInt = std.fmt.parseInt;
const heap = std.heap;
const process = std.process;
const print = std.debug.print;
const Chameleon = @import("chameleon");
const SuperFile = @import("./super_file.zig").SuperFile;

pub fn includes(buffer: []const u8, search: []const u8) bool {
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

pub fn contains(array: [][]const u8, search: []const u8) bool {
    for (array) |item| {
        if (equal(u8, item, search)) {
            return true;
        }
    }

    return false;
}

pub fn strip_installation(content: []u8) ![][]const u8 {
    var lines = splitSequence(u8, content, "\n");
    var ignore = false;

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    while (lines.next()) |line| {
        if (includes(line, "#openwrt-led-night-mode-start")) {
            ignore = true;
        } else if (includes(line, "#openwrt-led-night-mode-end")) {
            ignore = false;
        } else if (!ignore) {
            try list.append(line);
        }
    }

    return list.toOwnedSlice();
}

pub fn get_args() ![][]u8 {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    errdefer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try process.argsAlloc(allocator);

    errdefer process.argsFree(allocator, args);

    return args;
}

pub fn print_header(command: []const u8) !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var c = Chameleon.initRuntime(.{ .allocator = allocator });
    defer c.deinit();

    print("{s} {s}\n\n", .{ try c.black().bgGreen().fmt(" openwrt led night mode ", .{}), command });
}

pub fn get_leds() ![][]const u8 {
    var dir = try fs.openDirAbsolute("/sys/class/leds/", .{ .iterate = true });
    defer dir.close();

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        // LEDs are stored as a symbolic links
        if (entry.kind == .sym_link) {
            try list.append(entry.name);
        }
    }

    return try list.toOwnedSlice();
}

pub const BuildCommandsOptions = struct { leds: [][]const u8, start_hour: u8, start_minute: u8, end_hour: u8, end_minute: u8 };

pub fn build_commands(options: BuildCommandsOptions) ![]u8 {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    errdefer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    try list.writer().print("#openwrt-led-night-mode-start\n", .{});

    for (options.leds) |led| {
        try list.writer().print("{d} {d} * * * echo 0 > /sys/class/leds/{s}/brightness\n", .{ options.start_minute, options.start_hour, led });
        try list.writer().print("{d} {d} * * * echo 1 > /sys/class/leds/{s}/brightness\n", .{ options.end_minute, options.end_hour, led });
    }

    try list.writer().print("#openwrt-led-night-mode-end\n", .{});

    return list.toOwnedSlice();
}

pub fn parse_args(args: [][]u8) !BuildCommandsOptions {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    errdefer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var start_hour: u8 = 22;
    var start_minute: u8 = 0;
    var end_hour: u8 = 7;
    var end_minute: u8 = 0;

    var i: u4 = 2;

    const system_leds = try get_leds();

    var custom_leds = std.ArrayList([]const u8).init(allocator);
    errdefer custom_leds.deinit();

    var used_custom_leds = false;

    while (i < args.len) : (i += 1) {
        const parameter = args[i];

        var parsed = splitSequence(u8, parameter, "=");

        const name = parsed.first()[2..];
        const value = parsed.next().?;

        // Time
        if (equal(u8, name, "start") or equal(u8, name, "end")) {
            var time = splitSequence(u8, value, ":");

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
        } else if (equal(u8, name, "leds")) {
            var it = splitSequence(u8, value, ",");

            while (it.next()) |led| {
                try custom_leds.append(led);

                if (!contains(system_leds, led)) {
                    std.debug.print("Unknown custom led: {s}\n", .{led});
                }
            }

            used_custom_leds = true;
        }
    }

    return BuildCommandsOptions{ .leds = if (used_custom_leds) try custom_leds.toOwnedSlice() else system_leds, .start_hour = start_hour, .start_minute = start_minute, .end_hour = end_hour, .end_minute = end_minute };
}

pub fn get_cron_file_stripped(allocator: mem.Allocator) !SuperFile {
    var superFile = try SuperFile.init("/var/spool/cron/crontabs/root");

    const content = try superFile.read(allocator);
    const stripped = try strip_installation(content);

    try superFile.clear();

    for (stripped, 0..) |line, idx| {
        try superFile.write(line);

        if (idx < stripped.len - 1) {
            try superFile.new_line();
        }
    }

    return superFile;
}

pub fn apply_cron_changes() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var child = process.Child.init(&[_][]const u8{ "/etc/init.d/cron", "restart" }, allocator);

    _ = try child.spawnAndWait();
}
