pub const DataType = @import("system/DataType.zig");
pub const Io = @import("system/Io.zig");
pub const Console = Io.Console;
pub const Fs = @import("system/Fs.zig");
pub const Memory = @import("system/Memory.zig");
pub const Process = @import("system/Process.zig");

pub const Cpu = @import("system/Cpu.zig");
pub const Os = @import("system/Os.zig");

const std = @import("std");
const builtin = @import("builtin");

cpu: Cpu,
os: Os,
abi: Os.Abi,
ofmt: Os.ObjectFormat,

pub fn getTotalMemory() !u64 {
    return try std.process.totalSystemMemory();
}

pub fn getOs() Os {
    const os = Os{
        .tag = builtin.os.tag,
        .version_range = builtin.os.version_range,
    };
    return os;
}

pub fn getAbi() Os.Abi {
    return builtin.abi;
}

pub fn getObjectFormat(os_tag: Os.Tag, arch: Cpu.Arch) Os.ObjectFormat {
    return std.Target.ObjectFormat.default(os_tag, arch);
}

pub fn getCpu() Cpu {
    const cpu = Cpu{
        .arch = builtin.cpu.arch,
        .features = builtin.cpu.features,
    };
    return cpu;
}

pub fn getCpuCount() !usize {
    return try std.Thread.getCpuCount();
}

pub fn isTest() bool {
    return builtin.is_test;
}

pub fn main(init: std.process.Init) !void {
    const memory_size = try System.getTotalMemory();
    Console.print2("memory_size={d}\n", .{
        memory_size,
    });
    const cpu_count = try System.getCpuCount();
    Console.print2("cpu_count={d}\n", .{
        cpu_count,
    });
    var env_map = init.environ_map;
    var iter = env_map.iterator();
    while (iter.next()) |pair| {
        Console.print2("{s} = {s}\n", .{
            pair.key_ptr.*,
            pair.value_ptr.*,
        });
    }
}

const System = @This();
