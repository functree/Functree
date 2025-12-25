const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const Compile = @import("functree/tool/Compile.zig");

const Str = []const u8;

const output_dir_name = ".funcfile";

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};

const normal_usage =
    \\Usage: Functree [source file path]
;

pub fn main() !void {
    const gpa = general_purpose_allocator.allocator();
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // const source_file_path: Str = "functree/functree/System.func";
    // const output_type = Compile.OutPutTypeMap.get("run");

    var out_put_type_str: Str = "";
    var source_file_path: Str = "";
    const args = try std.process.argsAlloc(arena);
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
    var output_dir = try createOutputDir(output_dir_name);
    defer {
        output_dir.close();
        std.fs.cwd().deleteTree(output_dir_name) catch {};
    }
    //Compile
    var compile = Compile.init(gpa, arena, .{
        .main_source_file_path = source_file_path,
        .output_dir_path = output_dir_name,
        .output_type = output_type.?,
        .extra_args = try extra_arg_list.toOwnedSlice(arena),
    });
    defer compile.deinit();

    _ = compile.make();
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}
fn createOutputDir(dir_name: Str) !std.fs.Dir {
    if (std.fs.cwd().openDir(dir_name, .{})) |dir| {
        return dir;
    } else |err| switch (err) {
        error.FileNotFound => {
            try std.fs.cwd().makeDir(dir_name);
            return std.fs.cwd().openDir(dir_name, .{});
        },
        else => |other_err| return other_err,
    }
}

test "compile variable" {
    const gpa = general_purpose_allocator.allocator();
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const source_file_path: Str = "functree/test/zig/CompileVariable.func";

    //创建输出目录
    _ = try createOutputDir(output_dir_name);
    //Compile
    var extra_arg_list: ArrayList([]const u8) = .empty;
    var compile = Compile.init(gpa, arena, .{
        .main_source_file_path = source_file_path,
        .output_dir_path = output_dir_name,
        .extra_args = try extra_arg_list.toOwnedSlice(arena),
    });
    defer compile.deinit();

    try std.testing.expectEqual(compile.make(), 0);
}

test "compile function" {
    const gpa = general_purpose_allocator.allocator();
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const source_file_path: Str = "functree/test/zig/CompileFunction.func";

    //创建输出目录
    _ = try createOutputDir(output_dir_name);
    //Compile
    var extra_arg_list: ArrayList([]const u8) = .empty;
    var compile = Compile.init(gpa, arena, .{
        .main_source_file_path = source_file_path,
        .output_dir_path = output_dir_name,
        .extra_args = try extra_arg_list.toOwnedSlice(arena),
    });
    defer compile.deinit();

    try std.testing.expectEqual(compile.make(), 0);
}
