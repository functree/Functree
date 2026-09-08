pub const File = @import("io/File.zig");
pub const Dir = @import("io/Dir.zig");

const Memory = @import("Memory.zig");
const String = @import("datatype/String.zig");

const std = @import("std");

pub fn isAbsolutePath(path: []const u8) bool {
    return std.fs.path.isAbsolute(path);
}

pub fn toAbsolutePath(memory: *Memory, relative_path: []const u8) ![]u8 {
    const io = memory.io();
    const current_dir = std.Io.Dir.cwd();
    const dir = try current_dir.openDir(io, relative_path, .{});
    var buffer: [1024]u8 = undefined;
    const len = try dir.realPath(io, &buffer);
    const path = buffer[0..len];
    return String.copyStr(memory, path);
}

pub fn joinPath(memory: *Memory, paths: []const []const u8) ![]u8 {
    return try std.fs.path.join(memory.allocator(), paths);
}

const Fs = @This();
