pub const Config = @import("functree/tool/Config.zig");

const System = @import("functree/tool/System.zig");
const Memory = System.Memory;
const Process = System.Process;
const Io = System.Io;
const Console = Io.Console;
const DataType = System.DataType;
const String = DataType.String;
const StringMap = DataType.StringMap;
const List = DataType.List;
const Fs = System.Fs;
const Dir = Fs.Dir;

const Compile = @import("functree/tool/Compile.zig");

const normal_usage =
    \\    Usage: Functree build-exe   [main source file path] [-...]
    \\           Functree build-lib   [main source file path] [-...]
    \\           Functree build-obj   [main source file path] [-...]
    \\           Functree test        [main source file path] [-...]
    \\           Functree run         [main source file path] [-...]
    \\           Functree version
    \\           Functree help
    \\
;
pub fn main(init: Process.Init) !void {
    var memory = Memory.a();
    memory.f();
    defer memory.d();
    const args = try init.minimal.args.toSlice(memory.allocator());
    if (args.len == 1) {
        Console.print2("{s}", .{normal_usage});
        return;
    }
    const output_type_str = args[1];
    if (!String.equalStr(output_type_str, "version") and !String.equalStr(output_type_str, "help") and args.len < 3) {
        Console.print2("{s}\n", .{normal_usage});
        fatal("Functree expected 2 args or more.", .{});
    } else {
        const output_type = Config.OutPutTypeMap.get(output_type_str);
        if (output_type == null) {
            Console.print2("{s}", .{normal_usage});
            fatal("only support 7 output type.", .{});
        }
        Config.output_type = output_type.?;
        if (output_type.? == .help) {
            Console.print2("{s}", .{normal_usage});
            return;
        } else if (output_type.? == .version) {
            Console.print2("{s}", .{Config.version});
            return;
        }
        const main_source_file_path = args[2];
        if (main_source_file_path.len < 6 or (!String.endWithStr(main_source_file_path[main_source_file_path.len - 5 ..], ".func") and !String.endWithStr(main_source_file_path[main_source_file_path.len - 5 ..], ".f"))) {
            Console.print2("{s}\n", .{normal_usage});
            fatal("main source file path is invalid, file's suffix must be `.func`.", .{});
        }
        // Functree.func
        if (!String.equalStr(main_source_file_path, "Functree.func")) {
            if (!String.startWithStr(main_source_file_path, "functree/")) {
                fatal("main source file path must begin with 'functree/'.", .{});
            }
            const backslash_pos = String.indexOfStr(main_source_file_path, "\\");
            if (backslash_pos) |_| {
                fatal("main source file path must be separated by '/'.", .{});
            }
        }
        Config.main_source_file_path = main_source_file_path;
    }
    var extra_arg_list = List.t([]const u8).a(&memory);
    if (args.len > 3) {
        for (args, 0..) |arg, index| {
            if (index >= 3) {
                try extra_arg_list.add(arg);
            }
        }
    }
    Config.extra_cmd_args = try extra_arg_list.toArray();
    var current_dir = try Dir.getCurrentDir(&memory);
    defer current_dir.d();
    const absolute_path = try current_dir.getAbsolutePath();
    const output_tmp_dir_absolute_path = try Fs.joinPath(&memory, &.{ absolute_path, Config.output_tmp_dir_path });
    if (Dir.existPath(&memory, output_tmp_dir_absolute_path)) {
        try Dir.deleteAll(&memory, output_tmp_dir_absolute_path);
    }
    try Dir.createDirPath(&memory, output_tmp_dir_absolute_path);
    Config.output_tmp_dir_absolute_path = output_tmp_dir_absolute_path;
    var compile = try Compile.a(&memory);
    defer {
        compile.d();
        if (!Config.reserve_target_code_file and !Config.reserve_token_file and !Config.reserve_code_node_file) {
            // Dir.deleteAll(&memory, Config.output_tmp_dir_absolute_path) catch {};
        }
    }
    compile.make(init.environ_map);
}
pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    Console.print2(format, args);
    Process.exit(1);
}

const Functree = @This();
