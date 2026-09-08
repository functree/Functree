pub const DependFunc = @import("func/DependFunc.zig");
pub const Token = @import("func/Token.zig");
const TokenIndex = Token.TokenIndex;
pub const Node = @import("func/Node.zig");
pub const Code = @import("func/Code.zig");

const System = @import("../System.zig");
const Memory = System.Memory;
const DataType = System.DataType;
const String = DataType.String;
const List = DataType.List;

memory: *Memory,
func_path: []const u8,
full_name: []const u8,
is_main_func: bool,

token_list: List.t(Token),
code_list: List.t(Code),
depend_func_list: List.t(DependFunc),

pub fn a(memory: *Memory, func_path: []const u8, is_main_func: bool) Func {
    const self = Func{
        .memory = memory,
        .func_path = func_path,
        .full_name = getFuncFullName(memory, func_path) catch "",
        .is_main_func = is_main_func,
        .token_list = List.t(Token).a(memory),
        .code_list = List.t(Code).a(memory),
        .depend_func_list = List.t(DependFunc).a(memory),
    };
    return self;
}

pub fn getFuncFullName(memory: *Memory, func_path: []const u8) ![]const u8 {
    const suffix_pos = String.lastIndexOfStr(func_path, ".");
    var func_name = try String.copyStr(memory, func_path[0..suffix_pos.?]);
    func_name = try String.replaceStr(memory, func_name, "/", ".");
    func_name = try String.replaceStr(memory, func_name, "\\", ".");
    return func_name;
}

pub fn appendCodeList(self: *Func, statement: Code) !void {
    try self.code_list.add(statement);
}
pub fn appendDependList(self: *Func, depend_func: DependFunc) !void {
    try self.depend_func_list.add(depend_func);
}

const Func = @This();
