const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const Compile = @import("functree/tool/Compile.zig");

const Str = []const u8;

const output_dir_name = ".funcfile";

// var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};

const normal_usage =
    \\Usage: Functree [command] [source file path]
;

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const gpa = switch (builtin.mode) {
        .Debug => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall, .ReleaseSafe => std.heap.smp_allocator,
    };
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var out_put_type_str: Str = "";
    var source_file_path: Str = "";
    const args = try init.minimal.args.toSlice(arena); // try std.process.argsAlloc(arena);
    if (args.len < 3) {
        std.log.info("{s}", .{normal_usage});
        fatal("Functree expected 2 args or more.", .{});
    } else {
        out_put_type_str = args[1];
        source_file_path = args[2];
    }
    const output_type = Compile.OutPutTypeMap.get(out_put_type_str);
    if (output_type == null) {
        std.log.info("{s}", .{normal_usage});
        fatal("only support 5 output type.", .{});
    }
    var extra_arg_list: ArrayList([]const u8) = .empty;
    if (args.len > 3) {
        for (args, 0..) |arg, index| {
            if (index >= 3) {
                try extra_arg_list.append(arena, arg);
            }
        }
    }

    if (source_file_path.len < 6 or !std.mem.eql(u8, source_file_path[source_file_path.len - 5 ..], ".func")) {
        std.log.info("{s}", .{normal_usage});
        fatal("source file path is invalid, file's suffix must be `.func`.", .{});
    }

    //创建输出目录
    var output_dir = try createOutputDir(init.io, output_dir_name);
    defer {
        output_dir.close(init.io);
        std.Io.Dir.cwd().deleteTree(init.io, output_dir_name) catch {};
    }
    //Compile
    var compile = Compile.init(gpa, arena, .{
        .main_source_file_path = source_file_path,
        .output_dir_path = output_dir_name,
        .output_type = output_type.?,
        .extra_args = try extra_arg_list.toOwnedSlice(arena),
    });
    defer compile.deinit();

    _ = compile.make(init.io, init.environ_map);
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}
fn createOutputDir(io: std.Io, dir_name: Str) !std.Io.Dir {
    if (std.Io.Dir.cwd().openDir(io, dir_name, .{})) |dir| {
        return dir;
    } else |err| switch (err) {
        error.FileNotFound => {
            try std.Io.Dir.cwd().createDir(io, dir_name, .default_file);
            return std.Io.Dir.cwd().openDir(io, dir_name, .{});
        },
        else => |other_err| return other_err,
    }
}
