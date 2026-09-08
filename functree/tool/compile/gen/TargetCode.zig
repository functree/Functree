const System = @import("../../System.zig");
const Memory = System.Memory;
const DataType = System.DataType;
const String = DataType.String;
const List = DataType.List;

memory: *Memory,
code_line_list: List.t([]const u8),

pub fn a(memory: *Memory) TargetCode {
    const self = TargetCode{
        .memory = memory,
        .code_line_list = List.t([]const u8).a(memory),
    };
    return self;
}

pub fn d(self: *TargetCode) void {
    for (self.code_line_list.values()) |value| {
        self.memory.free2(value);
    }
    self.code_line_list.d();
    self.* = undefined;
}

pub fn appendCodeLineList(self: *TargetCode, line: []const u8) !void {
    try self.code_line_list.add(try String.copyStr(self.memory, line));
}

const TargetCode = @This();
