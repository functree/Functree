const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Func = @import("Func.zig").Func;
const TargetStatement = @import("Translate.zig").TargetStatement;

pub fn generateTargetStatementList(allocator: Allocator, io: std.Io, func: Func, target_statement_list: *ArrayList(TargetStatement)) !void {
    _ = try @import("zig/GenerateCode.zig").init(allocator, io, func, target_statement_list);
}
