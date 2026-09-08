const Memory = @import("Memory.zig");
const Console = @import("io/Console.zig");

// pub const Thread = @import("process/Thread.zig");

const std = @import("std");

pub const Init = std.process.Init;
pub const Environ = std.process.Environ;
pub const RunResult = std.process.RunResult;

/// run process
pub fn run(memory: *Memory, argv: [][]const u8, environ_map: *Environ.Map) !void {
    const io = memory.io();
    const term_result = (term: {
        _ = try io.lockStderr(&.{}, .no_color);
        defer io.unlockStderr();

        var child = std.process.spawn(io, .{
            .argv = argv,
            .environ_map = environ_map,
            .stdin = .inherit,
            .stdout = .inherit,
            .stderr = .inherit,
        }) catch |err| break :term err;
        defer child.kill(io);

        break :term child.wait(io);
    });

    _ = term_result catch |err| {
        const cmd = try std.mem.join(memory.allocator(), " ", argv);
        Console.print2("the following command failed with {t}:\n{s}", .{ err, cmd });
    };
}
fn run2(memory: *Memory, argv: []const []const u8, io: std.Io) !Process {
    const allocator = memory.allocator();
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
    });
    if (!memory.auto_free) {
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
    }

    return Process{ .argv = argv, .memory = memory, .result = result };
}
/// Exits all threads of the program with the specified status code.
pub fn exit(status: u8) noreturn {
    std.process.exit(status);
}

argv: []const []const u8,
memory: *Memory,
result: RunResult,

pub fn a(memory: *Memory, argv: []const []const u8) !Process {
    return try Process.run2(memory, argv, memory.io());
}
pub fn a2(memory: *Memory, argv: []const []const u8, io: std.Io) !Process {
    return try Process.run2(memory, argv, io);
}

pub fn d(self: *Process) void {
    self.* = undefined;
}

const Process = @This();
