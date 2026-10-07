pub const Reader = std.Io.File.Reader;
pub const Writer = std.Io.File.Writer;

pub const Kind = std.Io.File.Kind;
pub const CreateFileOptions = std.Io.Dir.CreateFileOptions;
pub const OpenFileOptions = std.Io.Dir.OpenFileOptions;
pub const OpenFileError = std.Io.File.OpenError;
pub const WriteFileOptions = std.Io.Dir.WriteFileOptions;
pub const DeleteFileError = std.Io.Dir.DeleteFileError;
pub const Stat = std.Io.File.Stat;

const System = @import("../../System.zig");
const Memory = System.Memory;
const DataType = System.DataType;
const String = DataType.String;

const Fs = @import("../Fs.zig");
const Dir = @import("Dir.zig");

const std = @import("std");

file: std.Io.File,
memory: *Memory,
io: std.Io,
reader: ?Reader = null,

pub fn a(memory: *Memory, file_path: []const u8) !File {
    const io = memory.io();
    var file: ?std.Io.File = null;
    var absolute_path = file_path;
    if (std.fs.path.isAbsolute(file_path)) {
        file = std.Io.Dir.openFileAbsolute(io, file_path, .{}) catch null;
    } else {
        file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch null;
        absolute_path = try Fs.toAbsolutePath(memory, file_path);
    }
    if (file == null) {
        return try create(memory, absolute_path);
    } else {
        return File{
            .file = file.?,
            .memory = memory,
            .io = io,
        };
    }
}
pub fn a2(memory: *Memory, file_path: []const u8, io: std.Io) !File {
    var file: ?std.Io.File = null;
    var real_path = file_path;
    if (std.fs.path.isAbsolute(file_path)) {
        file = std.Io.Dir.openFileAbsolute(io, file_path, .{}) catch null;
    } else {
        file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch null;
        real_path = try Fs.toAbsolutePath(memory, file_path);
    }
    if (file == null) {
        return try create(memory, real_path);
    } else {
        return File{
            .file = file.?,
            .memory = memory,
            .io = io,
        };
    }
}
pub fn d(self: *File) void {
    self.file.close(self.io);
    self.* = undefined;
}
pub fn getLength(self: File) !u64 {
    return try self.file.length(self.memory.io());
}
pub fn stat(self: File) !Stat {
    return try self.file.stat(self.memory.io());
}
pub fn read(self: *File, buffer: []u8) !usize {
    if (self.reader == null) {
        self.reader = self.file.reader(self.io, &.{});
    }
    return try self.reader.?.interface.readSliceShort(buffer);
}
pub fn readAll(self: File) ![]u8 {
    const file_len = try self.file.length(self.io);
    if (file_len == 0) return "";
    const buffer = try self.memory.alloc2(u8, file_len);
    const n = try self.file.readPositionalAll(self.io, buffer, 0);
    if (n == 0) {
        return "";
    } else {
        return buffer;
    }
}

pub fn append(self: File, value: []const u8) !void {
    try self.file.writeStreamingAll(self.io, value);
}

pub fn writeAll(self: File, value: []const u8) !void {
    var writer = self.file.writer(self.io, &.{});
    try writer.interface.writeAll(value);
}

pub fn create(memory: *Memory, absolute_path: []const u8) OpenFileError!File {
    const io = memory.io();
    const file = try std.Io.Dir.createFileAbsolute(io, absolute_path, .{
        .read = true,
    });
    return File{
        .file = file,
        .memory = memory,
        .io = io,
    };
}
pub fn create2(memory: *Memory, absolute_path: []const u8, create_flags: CreateFileOptions) OpenFileError!File {
    const io = memory.io();
    const file = try std.Io.Dir.createFileAbsolute(io, absolute_path, create_flags);
    return File{
        .file = file,
        .memory = memory,
        .io = io,
    };
}
pub fn delete(absolute_path: []const u8) DeleteFileError!void {
    try std.Io.Dir.deleteFileAbsolute(absolute_path);
}
pub fn open(memory: *Memory, file_path: []const u8) OpenFileError!File {
    const io = memory.io();
    var file: ?std.Io.File = null;
    if (std.fs.path.isAbsolute(file_path)) {
        file = try std.Io.Dir.openFileAbsolute(io, file_path, .{});
    } else {
        file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    }
    return File{
        .file = file.?,
        .memory = memory,
        .io = io,
    };
}
pub fn open2(memory: *Memory, file_path: []const u8, open_flags: OpenFileOptions) OpenFileError!File {
    const io = memory.io();
    var file: ?std.Io.File = null;
    if (std.fs.path.isAbsolute(file_path)) {
        file = try std.Io.Dir.openFileAbsolute(io, file_path, open_flags);
    } else {
        file = try std.Io.Dir.cwd().openFile(io, file_path, open_flags);
    }
    return File{
        .file = file.?,
        .memory = memory,
        .io = io,
    };
}

const File = @This();
