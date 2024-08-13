const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const equal = mem.eql;
const split = mem.split;
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

pub fn strip_installation(content: []u8) ![][]const u8 {
    var lines = split(u8, content, "\n");
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

pub fn build_commands(start_hour: u8, start_minute: u8, end_hour: u8, end_minute: u8) ![]u8 {
    const leds = try get_leds();

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    errdefer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    try list.writer().print("#openwrt-led-night-mode-start\n", .{});

    for (leds) |led| {
        try list.writer().print("{d} {d} * * * echo 0 > /sys/class/leds/{s}/brightness\n", .{ start_minute, start_hour, led });
        try list.writer().print("{d} {d} * * * echo 1 > /sys/class/leds/{s}/brightness\n", .{ end_minute, end_hour, led });
    }

    try list.writer().print("#openwrt-led-night-mode-end\n", .{});

    return list.toOwnedSlice();
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
