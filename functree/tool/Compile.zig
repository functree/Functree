const System = @import("System.zig");
const Memory = System.Memory;
const Process = System.Process;
const Io = System.Io;
const Console = Io.Console;
const Fs = System.Fs;
const Dir = Fs.Dir;
const File = Fs.File;
const DataType = System.DataType;
const String = DataType.String;
const List = DataType.List;
const StringMap = DataType.StringMap;
const StaticStringMap = DataType.StaticStringMap;

const Config = @import("Config.zig");

const Parse = @import("compile/Parse.zig");
const Func = @import("compile/Func.zig");
const Gen = @import("compile/Gen.zig");

memory: *Memory,

target_main_source_file_path: []const u8 = undefined,
total_line_count: u64,
depend_func_map: StringMap.t(Func),

pub fn a(memory: *Memory) !Compile {
    const self = Compile{
        .memory = memory,
        .total_line_count = 0,
        .depend_func_map = StringMap.t(Func).a(memory),
    };
    return self;
}

pub fn d(self: *Compile) void {
    self.depend_func_map.d();
    self.* = undefined;
}

pub fn make(self: *Compile, environ_map: *Process.Environ.Map) void {
    const _func = self.parseFuncSourceFile() catch |err| {
        Console.print2("Compile.make parse error: {}", .{err});
        return;
    };
    if (_func != null) {
        self.makeTargetFile(environ_map) catch |err| {
            Console.print2("Compile.make error: {}", .{err});
        };
    } else {
        Console.print2("Compile.make main func is null", .{});
    }
}
fn parseFuncSourceFile(self: *Compile) !?Func {
    var parse = Parse.a(self.memory);
    defer parse.d();
    const _func = try parse.parseFuncSource(Config.main_source_file_path, true);
    try self.depend_func_map.add(_func.full_name, _func);
    try self.parseFuncDependSourceCode(_func);
    self.target_main_source_file_path = try self.getTargetMainFuncFilePath(_func);
    try self.genTargetFuncFile(_func, true);
    return _func;
}

fn makeTargetFile(self: *Compile, environ_map: *Process.Environ.Map) !void {
    var argv = List.t([]const u8).a(self.memory);
    defer argv.d();
    try argv.add("zig");
    switch (Config.output_type) {
        .build_exe => try argv.add("build-exe"),
        .build_lib => try argv.add("build-lib"),
        .build_obj => try argv.add("build-obj"),
        .run => try argv.add("run"),
        ._test => try argv.add("test"),
        else => {},
    }
    try argv.add(self.target_main_source_file_path);
    try argv.addArray(Config.extra_cmd_args);
    try Process.run(self.memory, argv.values(), environ_map);
}

fn parseFuncDependSourceCode(self: *Compile, _func: Func) !void {
    for (_func.depend_func_list.values()) |depend| {
        if (self.depend_func_map.hasKey(depend.full_name)) {
            continue;
        }
        var parse = Parse.a(self.memory);
        defer parse.d();
        const depend_func = parse.parseFuncSource(depend.func_path, false) catch |err| {
            Console.print2("{s}: parseFuncDependSourceCode error: {any}\n", .{ _func.func_path, err });
            return err;
        };
        try self.depend_func_map.add(depend_func.full_name, depend_func);
        try self.parseFuncDependSourceCode(depend_func);
        try self.genTargetFuncFile(depend_func, false);
    }
}

fn getTargetFuncFilePath(self: *Compile, _func: Func) ![]u8 {
    const suffix_pos = String.lastIndexOfStr(_func.func_path, ".");
    var func_path = try String.copyStr(self.memory, _func.func_path[0..suffix_pos.?]);
    // Functree.func
    if (!String.equalStr(_func.func_path, "Functree.func")) {
        func_path = try String.copyStr(self.memory, _func.func_path[0..suffix_pos.?]);
        const last_slash_pos = String.lastIndexOfStr(func_path, "/");
        const dir_path = try String.copyStr(self.memory, func_path[0..last_slash_pos.?]);
        const dir_path_absolute = try Fs.joinPath(self.memory, &.{ Config.output_tmp_dir_absolute_path, "/", dir_path });
        // 创建父目录
        if (!Dir.existPath(self.memory, dir_path_absolute)) {
            var path = try String.copyStr(self.memory, Config.output_tmp_dir_absolute_path);
            const dir_name_array = try String.splitStr(dir_path, "/");
            for (dir_name_array) |dir_name| {
                path = try Fs.joinPath(self.memory, &.{ path, "/", dir_name });
                if (!Dir.existPath(self.memory, path)) {
                    try Dir.createDirPath(self.memory, path);
                }
            }
        }
    }
    const target_file_path = try String.concatStr(self.memory, &.{ func_path, ".zig" });
    return try String.formatStr(self.memory, "{s}{s}{s}", .{ Config.output_tmp_dir_path, "/", target_file_path });
}
fn getTargetMainFuncFilePath(self: *Compile, _func: Func) ![]u8 {
    const func_name = try String.replaceStr(self.memory, _func.full_name, ".", "_");
    const target_file_name = try String.concatStr(self.memory, &.{ func_name, ".zig" });
    return try String.formatStr(self.memory, "{s}{s}{s}", .{ Config.output_tmp_dir_path, "/", target_file_name });
}
fn genTargetFuncFile(self: *Compile, _func: Func, is_main_func: bool) !void {
    const target_file_path = if (is_main_func) try self.getTargetMainFuncFilePath(_func) else try self.getTargetFuncFilePath(_func);
    var target_file = try File.create(self.memory, target_file_path);
    defer target_file.d();
    const target_code_list = try Gen.genTargetCodeList(self.memory, _func);
    for (target_code_list.values()) |target_code| {
        for (target_code.code_line_list.values()) |code_line| {
            _ = try target_file.append(code_line);
        }
    }
}

const Compile = @This();
