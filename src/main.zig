const std = @import("std");
const fs = std.fs;
const process = std.process;
const heap = std.heap;
const GeneralPurposeAllocator = heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const equal = std.mem.eql;

fn get_crontab_file_location() []u8 {
    return "/var/spool/cron/crontabs/root";
}

fn get_leds() ![][]const u8 {
    var dir = try fs.openDirAbsolute("/sys/class/leds/", .{ .iterate = true });
    defer dir.close();

    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer _ = gpa.deinit();

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
    const leds = try get_leds();

    for (leds) |led| {
        std.debug.print("{s}\n", .{led});
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

pub fn main() !void {
    // todo: make uninstall command, make install command --start flag, make --end flag
    // when running override (remove & add again) new things
    // program should edit file with shit

    const args = try get_args();
    const command = args[1];

    if (equal(u8, command, "list")) {
        try print_leds();
    } else if (equal(u8, command, "help")) {
        const text =
            \\help — print help
            \\list — print all LED's
            \\
        ;

        std.debug.print(text, .{});
    }
}
