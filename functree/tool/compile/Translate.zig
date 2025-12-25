const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Func = @import("Func.zig").Func;
const Statement = @import("Func.zig").Statement;
const GenerateCode = @import("GenerateCode.zig");

const Str = []const u8;

pub const Translator = @This();

allocator: Allocator,
target_file_path: Str,
main_func: Func,
col_no: usize = 0,
reached_eof: bool = false,

pub fn init(allocator: Allocator, target_file_path: Str, main_func: Func) Translator {
    const self = Translator{
        .allocator = allocator,
        .target_file_path = target_file_path,
        .main_func = main_func,
    };
    return self;
}

pub fn deinit(self: *Translator) void {
    self.* = undefined;
}

pub fn copyString(self: *Translator, value: Str) ![]u8 {
    return self.allocator.dupe(u8, value);
}

pub fn generateTargetStatementList(self: *Translator) !ArrayList(TargetStatement) {
    var target_code_list: ArrayList(TargetStatement) = .empty;

    // std.debug.print("FuncName=={s}\n", .{self.main_func.name});
    try GenerateCode.generateTargetStatementList(self.allocator, self.main_func, &target_code_list);

    return target_code_list;
}

pub const TargetStatement = struct {
    allocator: Allocator,
    line_no: usize,
    code_line_list: ArrayList(Str),

    pub fn init(allocator: Allocator, line_no: usize) TargetStatement {
        const self = TargetStatement{
            .allocator = allocator,
            .line_no = line_no,
            .code_line_list = .empty,
        };
        return self;
    }

    pub fn deinit(self: *TargetStatement) void {
        for (self.code_line_list.items) |item| {
            self.code_line_list.allocator.free(item);
        }
        self.code_line_list.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn copyString(self: TargetStatement, value: Str) ![]u8 {
        return self.allocator.dupe(u8, value);
    }

    pub fn appendCodeLineList(self: *TargetStatement, line: Str) !void {
        try self.code_line_list.append(self.allocator, try self.copyString(line));
    }
};
