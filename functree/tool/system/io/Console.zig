const std = @import("std");

const Memory = @import("../Memory.zig");

memory: *Memory,

pub fn a(memory: *Memory) Console {
    const self = Console{
        .memory = memory,
    };
    return self;
}

pub fn d(self: *Console) void {
    self.* = undefined;
}

pub fn input(self: *Console, delimiter: u8) ![]const u8 {
    const io = self.memory.io();
    var in_buffer: [4096]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &in_buffer);
    const stdin = &reader.interface;

    const line = try stdin.takeDelimiterExclusive(delimiter);
    return std.mem.trimEnd(u8, line, "\r");
}

const builtin = @import("builtin");
// 手动定义 Windows API 调用约定
const WINAPI: std.lang.CallingConvention = switch (builtin.target.cpu.arch) {
    .x86 => .stdcall,
    else => .c,
};
// 手动定义所需的 Windows 基础类型
const UINT = u32;
const BOOL = i32;

// 声明外部 kernel32.dll 函数
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: UINT) callconv(WINAPI) BOOL;
/// 设置控制台UTF8编码，跨平台兼容
pub fn setWindowsConsoleUtf8() void {
    if (builtin.target.os.tag != .windows) return;

    // 调用声明的函数，将控制台输出代码页设置为 UTF-8 (65001)
    _ = SetConsoleOutputCP(65001);
}

pub fn output(self: *Console, message: []const u8) !void {
    const io = self.memory.io();
    var out_buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &out_buffer);
    const stdout = &writer.interface;
    try stdout.writeAll(message);
    try stdout.flush();
}

pub fn print(string: []const u8) void {
    std.debug.print("{s}", .{
        string,
    });
}
pub fn println(string: []const u8) void {
    std.debug.print("{s}\n", .{
        string,
    });
}
pub fn print2(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
}

const Console = @This();
