const std = @import("std");
const heap = std.heap;
const GeneralPurposeAllocator = heap.GeneralPurposeAllocator;
const equal = std.mem.eql;
const utils = @import("./utils.zig");
const commands = @import("./commands.zig");

pub fn main() !void {
    const args = try utils.get_args();
    const command = args[1];

    if (args.len == 1 or equal(u8, command, "help")) {
        try commands.help();
    } else if (equal(u8, command, "list")) {
        try commands.list();
    } else if (equal(u8, command, "install")) {
        try commands.install(args);
    } else if (equal(u8, command, "uninstall")) {
        try commands.uninstall();
    }
}
