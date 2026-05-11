const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const process = std.process;

const Util = @import("compile/Util.zig");
const Str = []const u8;

const Func = @import("compile/Func.zig");
const Statement = Func.Statement;
const Token = Func.Token;
const Dependency = Func.Dependency;
const Parse = @import("compile/Parse.zig");
const Translate = @import("compile/Translate.zig");

const Compile = @This();
const sep = std.fs.path.sep;
const builtin = @import("builtin");
const native_os = builtin.os.tag;

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
/// Arena-allocated memory, mostly used during initialization. However, it can
/// be used for other things requiring the same lifetime as the program.
arena: Allocator,

config: Config,
target_main_source_file_path: ?Str = null,
total_line_count: u64,
depend_func_map: StringHashMap(Func),
translated_func_name_list: ArrayList(Str),

pub fn init(gpa: Allocator, arena: Allocator, config: Config) Compile {
    const self = Compile{
        .gpa = gpa,
        .arena = arena,
        .config = config,
        .total_line_count = 0,
        .depend_func_map = StringHashMap(Func).init(arena),
        .translated_func_name_list = .empty,
    };
    return self;
}

pub fn deinit(self: *Compile) void {
    self.* = undefined;
}

pub fn make(self: *Compile, io: std.Io, environ_map: *std.process.Environ.Map) usize {
    const func = self.parseFuncFile(io) catch null;
    if (func != null) {
        self.makeTargetFile(io, environ_map) catch return 2;
    } else {
        return 1;
    }
    return 0;
}

fn makeTargetFile(self: *Compile, io: std.Io, environ_map: *std.process.Environ.Map) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(self.gpa);
    try argv.appendSlice(self.gpa, &[_][]const u8{"zig"});
    switch (self.config.output_type) {
        .build_exe => try argv.appendSlice(self.gpa, &[_][]const u8{"build-exe"}),
        .build_lib => try argv.appendSlice(self.gpa, &[_][]const u8{"build-lib"}),
        .build_obj => try argv.appendSlice(self.gpa, &[_][]const u8{"build-obj"}),
        .run => try argv.appendSlice(self.gpa, &[_][]const u8{"run"}),
        ._test => try argv.appendSlice(self.gpa, &[_][]const u8{"test"}),
    }
    try argv.appendSlice(self.gpa, &[_][]const u8{self.target_main_source_file_path.?});
    try argv.appendSlice(self.gpa, self.config.extra_args);
    const self_exe_path: ?[]const u8 = if (!process.can_spawn)
        null
    else
        findZigExePath(io, self.arena) catch |err| {
            fatal("unable to find zig self exe path: {s}", .{@errorName(err)});
        };
    try environ_map.put("ZIG_EXE", self_exe_path.?);

    try self.exe(io, argv.items, environ_map);
    // const result = std.process.run(self.arena, io, .{
    //     .argv = argv.items,
    // }) catch |err| return fatal("failed to run {s}: {t}", .{ argv.items[0], err });
    // if (result.stderr.len > 0) {
    //     std.log.info("\n{s}", .{result.stderr});
    // }
}
fn exe(self: *Compile, io: std.Io, argv: [][]const u8, environ_map: *std.process.Environ.Map) !void {
    if (process.can_replace and (self.config.output_type == .run or self.config.output_type == ._test)) {
        // process replacement releases the locks; no need to destroy the Compilation here.
        _ = try io.lockStderr(&.{}, .no_color);
        const err = process.replace(io, .{ .argv = argv, .environ_map = environ_map });
        io.unlockStderr();
        const cmd = try std.mem.join(self.arena, " ", argv);
        fatal("the following command failed to execve with '{t}':\n{s}", .{ err, cmd });
    } else if (!process.can_spawn) {
        const cmd = try std.mem.join(self.arena, " ", argv);
        fatal("the following command cannot be executed ({t} does not support spawning a child process):\n{s}", .{
            native_os, cmd,
        });
    }
    const term_result = (term: {
        _ = try io.lockStderr(&.{}, .no_color);
        defer io.unlockStderr();

        var child = process.spawn(io, .{
            .argv = argv,
            .environ_map = environ_map,
            .stdin = .inherit,
            .stdout = .inherit,
            .stderr = .inherit,
        }) catch |err| break :term err;
        defer child.kill(io);

        break :term child.wait(io);
    });

    const term = term_result catch |err| {
        const cmd = try std.mem.join(self.arena, " ", argv);
        fatal("the following command failed with {t}:\n{s}", .{ err, cmd });
    };
    switch (self.config.output_type) {
        .run, .build_exe, .build_lib, .build_obj => {
            switch (term) {
                .exited => |code| {
                    if (code == 0) {
                        return process.cleanExit(io);
                    } else {
                        process.exit(code);
                    }
                },
                .signal => |sig| {
                    const cmd = try std.mem.join(self.arena, " ", argv);
                    fatal("the following command terminated with signal {t}:\n{s}", .{ sig, cmd });
                },
                .stopped => |sig| {
                    const cmd = try std.mem.join(self.arena, " ", argv);
                    fatal("the following command stopped with signal {t}:\n{s}", .{ sig, cmd });
                },
                .unknown => {
                    process.exit(1);
                },
            }
        },
        ._test => {
            switch (term) {
                .exited => |code| {
                    if (code == 0) {
                        return process.cleanExit(io);
                    } else {
                        const cmd = try std.mem.join(self.arena, " ", argv);
                        fatal("the following test command failed with exit code {d}:\n{s}", .{ code, cmd });
                    }
                },
                .signal => |sig| {
                    const cmd = try std.mem.join(self.arena, " ", argv);
                    fatal("the following test command terminated with signal {t}:\n{s}", .{ sig, cmd });
                },
                else => {
                    const cmd = try std.mem.join(self.arena, " ", argv);
                    fatal("the following test command crashed:\n{s}", .{cmd});
                },
            }
        },
    }
}
pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    process.exit(1);
}
/// This is a small wrapper around selfExePathAlloc that adds support for WASI
/// based on a hard-coded Preopen directory ("/zig")
pub fn findZigExePath(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    // return std.fs.selfExePathAlloc(allocator);
    return std.process.executablePathAlloc(io, allocator);
}

fn printFuncStatementTokenList(statement_list: ArrayList(Func.Statement)) void {
    std.debug.print("statement_list.items.len = {d}\n", .{statement_list.items.len});
    for (statement_list.items) |statement| {
        std.debug.print("statement line_no = {d}, statement.child_list.items.len = {d}\n", .{ statement.line_no, statement.child_list.items.len });
        for (statement.token_list.items) |token| {
            std.debug.print("token.text2 = '{s}', token.line_no = '{d}', token.column_no = {d}, token_type={any}\n", .{ token.text, token.line_no, token.column_no, token.token_type });
        }
        if (statement.child_list.items.len > 0) {
            printFuncStatementTokenList(statement.child_list);
        }
    }
}
fn parseFuncFile(self: *Compile, io: std.Io) !?Func {
    //parse source_code
    var parse = Parse.init(self.gpa, self.arena);
    defer parse.deinit();
    // parse main file
    // std.debug.print("parseFuncFile source_file_path: {s}\n", .{source_file_path});
    const func = parse.parseFuncSourceCode(io, self.config.main_source_file_path) catch |err| {
        // std.debug.print("parseFuncFile error: {any}\n", .{err});
        for (parse.errors.items) |item| {
            std.debug.print("{s}:{d}:{d}: error: {s}\n    {s}\n", .{ item.func_name, item.line_no, item.column_no, item.error_text, try item.statement.getText() });
        }
        return err;
    };

    try self.depend_func_map.put(func.name, func);
    try self.parseFuncDependSourceCode(io, func);

    // printFuncStatementTokenList(func.statement_list);

    self.target_main_source_file_path = try self.getTargetFuncFilePath(func);
    try self.translateFuncFile(io, func);

    return func;
}
fn parseFuncDependSourceCode(self: *Compile, io: std.Io, func: Func) !void {
    for (func.depend_func_list.items) |depend| {
        if (self.depend_func_map.contains(depend.func_name)) {
            continue;
        }
        var parse = Parse.init(self.gpa, self.arena);
        defer parse.deinit();
        // std.debug.print("parseFuncFile depend_func_list: {s}={s}\n", .{ depend.func_name, depend.func_path });
        const _func = parse.parseFuncSourceCode(io, depend.func_path) catch |err| {
            // std.debug.print("parseDependFuncFile: {any}\n", .{err});
            for (parse.errors.items) |item| {
                std.debug.print("{s}:{d}:{d}: error: {s}\n    {s}", .{ item.func_name, item.line_no, item.column_no, item.error_text, try item.statement.getText() });
            }
            return err;
        };
        try self.depend_func_map.put(_func.name, _func);
        try self.parseFuncDependSourceCode(io, _func);
        try self.translateFuncFile(io, _func);
    }
}
fn getTargetFuncFilePath(self: *Compile, func: Func) ![]u8 {
    const func_name = try std.mem.replaceOwned(u8, self.arena, func.name, ".", "_");
    const target_file_name = try Util.concat(self.arena, &.{ func_name, ".zig" });
    return try std.fmt.allocPrint(self.arena, "{s}{c}{s}", .{ self.config.output_dir_path, sep, target_file_name });
}
fn translateFuncFile(self: *Compile, io: std.Io, func: Func) !void {
    try self.translated_func_name_list.append(self.arena, func.name);

    //translate target_code
    const target_file_path = try self.getTargetFuncFilePath(func);
    var translate = Translate.init(self.arena, target_file_path, func);
    const target_statement_list = try translate.generateTargetStatementList(io);
    const target_file = try std.Io.Dir.cwd().createFile(
        io,
        target_file_path,
        .{ .read = true },
    );
    defer target_file.close(io);
    var current_line_no: usize = 1;
    for (target_statement_list.items) |target_statement| {
        // std.debug.print(">>>>>>>>>>>target_statement=={d},{d}\n", .{ target_statement.code_line_list.items.len, target_statement.line_no });
        while (current_line_no < target_statement.line_no) {
            // const info = std.fmt.allocPrint(self.arena, "{s}{d}", .{ "//", current_line_no }) catch "";
            // _ = try target_file.write("\n");
            try target_file.writeStreamingAll(io, "\n");
            current_line_no += 1;
        }
        for (target_statement.code_line_list.items) |code_line| {
            // _ = try target_file.write(code_line);
            try target_file.writeStreamingAll(io, code_line);
            const line_count = countUtf8Char(code_line, "\n");
            current_line_no += line_count;
        }
    }
}

fn countUtf8Char(s: Str, char: Str) usize {
    var count: usize = 0;
    var source_utf8_view = unicode.Utf8View.init(s) catch unreachable;
    var source_code_iterator = source_utf8_view.iterator();
    while (source_code_iterator.nextCodepointSlice()) |utf8_char| {
        if (Util.isEql(utf8_char, char)) {
            count += 1;
        }
    }
    return count;
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
fn get_file_name(path: Str) !Str {
    var filename = path;
    const index = std.mem.lastIndexOfScalar(u8, path, '/') orelse return path;
    if (index > 0) filename = path[index + 1 .. path.len];
    return filename;
}

pub const Config = struct {
    main_source_file_path: Str,
    output_dir_path: Str,
    output_type: OutPutType = .run, //.build-exe, .build-lib, .run, ._test
    extra_args: [][]const u8,
};
const OutPutType = enum {
    build_exe,
    build_lib,
    build_obj,
    // cc,
    // cpp,
    // translate_c,
    _test,
    run,
};
pub const OutPutTypeMap = std.StaticStringMap(OutPutType).initComptime(.{
    .{ "build-exe", .build_exe },
    .{ "build-lib", .build_lib },
    .{ "build-obj", .build_obj },
    .{ "test", ._test },
    .{ "run", .run },
});
