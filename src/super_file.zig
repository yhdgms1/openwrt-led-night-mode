const std = @import("std");
const fs = std.fs;

pub const SuperFile = struct {
    path: []const u8,
    file: fs.File,

    pub fn init(path: []const u8) !SuperFile {
        const file = fs.cwd().openFile(path, .{ .mode = .read_write }) catch try fs.cwd().createFile(path, .{});

        return SuperFile{
            .file = file,
            .path = path,
        };
    }

    pub fn deinit(self: *SuperFile) void {
        self.file.close();
    }

    pub fn read(self: *SuperFile, alloc: std.mem.Allocator) ![]u8 {
        return self.file.readToEndAlloc(alloc, 8 * 1024);
    }

    pub fn clear(self: *SuperFile) !void {
        self.file.close();
        self.file = try fs.cwd().createFile(self.path, .{});
    }
};
