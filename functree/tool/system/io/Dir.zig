const Memory = @import("../Memory.zig");
const String = @import("../datatype/String.zig");

const Fs = @import("../Fs.zig");
const File = @import("File.zig");

const std = @import("std");
const builtin = @import("builtin");

const TmpDir = std.testing.TmpDir;

pub const MakeDirError = std.Io.Dir.MakeError;
pub const OpenDirError = std.Io.Dir.OpenError;
pub const CopyFileOptions = std.Io.Dir.CopyFileOptions;
pub const CopyFileError = std.Io.Dir.CopyFileError;
pub const Entry = std.Io.Dir.Entry;

const native_os = builtin.os.tag;
const posix = std.posix;
const windows = std.os.windows;

pub const OpenOptions = std.Io.Dir.OpenOptions;
pub const Iterator = std.Io.Dir.Iterator;

dir: std.Io.Dir,
memory: *Memory,
io: std.Io,

pub fn a(memory: *Memory, absolute_path: []const u8) !Dir {
    const io = memory.io();
    var dir = std.Io.Dir.openDirAbsolute(io, absolute_path, .{
        .iterate = true,
    }) catch null;
    if (dir == null) {
        try createDirPath(memory, absolute_path);
        dir = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{
            .iterate = true,
        });
    }
    return Dir{
        .dir = dir.?,
        .memory = memory,
        .io = io,
    };
}
pub fn a2(memory: *Memory, absolute_path: []const u8, io: std.Io) !Dir {
    var dir = std.Io.Dir.openDirAbsolute(io, absolute_path, .{
        .iterate = true,
    }) catch null;
    if (dir == null) {
        try createDirPath(memory, absolute_path);
        dir = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{
            .iterate = true,
        });
    }
    return Dir{
        .dir = dir.?,
        .memory = memory,
        .io = io,
    };
}
pub fn d(self: *Dir) void {
    self.dir.close(self.io);
    self.* = undefined;
}
pub fn getCurrentDir(memory: *Memory) !Dir {
    const io = memory.io();
    const dir = std.Io.Dir.cwd();
    var buffer: [1024]u8 = undefined;
    const len = try dir.realPath(io, &buffer);
    const absolute_path = buffer[0..len];
    const dir2 = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{
        .iterate = true,
    });
    return Dir{
        .dir = dir2,
        .memory = memory,
        .io = io,
    };
}

/// get a temp dir's absolute path
pub fn getTempDir(memory: *Memory) !Dir {
    const io = memory.io();
    const random_dir_name = try getRandomName(memory.allocator(), 16);
    const temp_dir_path = try Fs.joinPath(memory, &.{ ".cache/tmp", random_dir_name });
    const cwd = std.Io.Dir.cwd();
    const dir = try cwd.createDirPathOpen(io, temp_dir_path, .{ .open_options = .{ .iterate = true } });
    //try cwd.createDirPath(io, temp_dir_path);
    //var buffer: [1024]u8 = undhefined;
    //const len = try cwd.realPath(io, &buffer);
    //var absolute_path = buffer[0..len];
    //absolute_path = try Fs.joinPath(memory, &.{absolute_path, temp_dir_path});
    //std.debug.print("absolute_pat={s}\n", .{absolute_path});
    //const dir = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{.iterate = true});
    return Dir{ .dir = dir, .memory = memory, .io = io };
}
fn getRandomName(alloc: std.mem.Allocator, length: usize) ![]u8 {
    var rand = std.Random.DefaultPrng.init(0);
    const r = rand.random();
    const char_set = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    const result = try alloc.alloc(u8, length);
    for (result) |*c| {
        c.* = char_set[r.uintLessThan(usize, char_set.len)];
    }

    return result;
}

pub fn exist(self: Dir, sub_path: []const u8) bool {
    self.dir.access(self.io, sub_path, .{}) catch return false;
    return true;
}
pub fn createDir(self: *Dir, sub_path: []const u8) !void {
    try self.dir.createDirPath(self.io, sub_path);
}
pub fn createDir2(self: *Dir, sub_path: []const u8) !void {
    try self.dir.createDir(self.io, sub_path, .default_file);
}
pub fn deleteDir(self: *Dir, sub_path: []const u8) !void {
    try self.dir.deleteDir(self.io, sub_path);
}
pub fn deleteDir2(self: *Dir, sub_path: []const u8) !void {
    try self.dir.deleteTree(self.io, sub_path);
}
pub fn openDir(self: *Dir, sub_path: []const u8) OpenDirError!Dir {
    const dir = try self.dir.openDir(self.io, sub_path, .{
        .iterate = true,
    });
    return Dir{
        .dir = dir,
        .memory = self.memory,
        .io = self.io,
    };
}
pub fn openDir2(self: *Dir, sub_path: []const u8, options: OpenOptions) OpenDirError!Dir {
    const dir = try self.dir.openDir(self.io, sub_path, options);
    return Dir{
        .dir = dir,
        .memory = self.memory,
        .io = self.io,
    };
}
pub fn getAbsolutePath(self: Dir) ![]u8 {
    var buffer: [1024]u8 = undefined;
    const len = try self.dir.realPath(self.io, &buffer);
    const absolute_path = buffer[0..len];
    return String.copyStr(self.memory, absolute_path);
}
pub fn setAsCurrentWorkDir(self: *Dir) !void {
    return try self.dir.setAsCwd();
}
pub fn iter(self: Dir) Iterator {
    return self.dir.iterate();
}
pub fn createFile(self: *Dir, sub_path: []const u8) !File {
    const file = try self.dir.createFile(self.io, sub_path, .{});
    return File{
        .file = file,
        .memory = self.memory,
        .io = self.io,
    };
}
pub fn createFile2(self: *Dir, sub_path: []const u8, flags: File.CreateFlags) !File {
    const file = try self.dir.createFile(self.io, sub_path, flags);
    return File{
        .file = file,
        .memory = self.memory,
        .io = self.io,
    };
}
pub fn openFile(self: *Dir, sub_path: []const u8, flags: File.OpenFlags) !File {
    const file = try self.dir.openFile(self.io, sub_path, flags);
    return File{
        .file = file,
        .memory = self.memory,
        .io = self.io,
    };
}
pub fn readFile(self: *Dir, sub_path: []const u8, buffer: []u8) ![]u8 {
    return try self.dir.readFile(sub_path, buffer);
}
pub fn deleteFile(self: *Dir, sub_path: []const u8) !void {
    return try self.dir.deleteFile(self.io, sub_path);
}
pub fn copyFile(memory: *Memory, source_path: []const u8, dest_path: []const u8) CopyFileError!void {
    try std.Io.Dir.copyFileAbsolute(source_path, dest_path, memory.io(), .{});
}
pub fn copyFile2(memory: *Memory, source_path: []const u8, dest_path: []const u8, options: CopyFileOptions) CopyFileError!void {
    try std.Io.Dir.copyFileAbsolute(source_path, dest_path, memory.io(), options);
}
pub fn openDirPath(memory: *Memory, absolute_path: []const u8) !Dir {
    const io = memory.io();
    const dir = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{
        .iterate = true,
    });
    return Dir{
        .dir = dir,
        .memory = memory,
        .io = io,
    };
}
pub fn openDirPath2(memory: *Memory, absolute_path: []const u8, options: OpenOptions) !Dir {
    const io = memory.io();
    const dir = try std.Io.Dir.openDirAbsolute(io, absolute_path, options);
    return Dir{
        .dir = dir,
        .memory = memory,
        .io = io,
    };
}
pub fn createDirPath(memory: *Memory, absolute_path: []const u8) !void {
    const io = memory.io();
    try std.Io.Dir.createDirAbsolute(io, absolute_path, .default_file);
}
pub fn renamePath(memory: *Memory, old_absolute_path: []const u8, new_absolute_path: []const u8) !void {
    const io = memory.io();
    return try std.Io.Dir.renameAbsolute(old_absolute_path, new_absolute_path, io);
}
pub fn existPath(memory: *Memory, absolute_path: []const u8) bool {
    const io = memory.io();
    std.Io.Dir.cwd().access(io, absolute_path, .{}) catch return false;
    return true;
}
pub fn deleteDirPath(memory: *Memory, absolute_path: []const u8) !void {
    const io = memory.io();
    try std.Io.Dir.deleteDirAbsolute(io, absolute_path);
}
pub fn deleteAll(memory: *Memory, absolute_path: []const u8) !void {
    const io = memory.io();
    const dir = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{});
    try dir.deleteTree(io, absolute_path);
}

const Dir = @This();
