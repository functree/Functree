pub const TokenParse = @import("parse/TokenParse.zig");
const TokenError = TokenParse.TokenError;
pub const CodeParse = @import("parse/CodeParse.zig");
const CodeError = CodeParse.CodeError;

const Config = @import("../Config.zig");

const System = @import("../System.zig");
const Memory = System.Memory;
const Io = System.Io;
const Console = Io.Console;
const Fs = System.Fs;
const File = Fs.File;
const DataType = System.DataType;
const Char = DataType.Char;
const String = DataType.String;
const List = DataType.List;
const StringMap = DataType.StringMap;

const Func = @import("Func.zig");

const DependFunc = Func.DependFunc;
const DependType = DependFunc.DependType;

const Code = Func.Code;

const Node = Func.Node;
const NodeType = Node.NodeType;
const NodeIndex = Node.NodeIndex;
const root_node_index = Node.root_node_index;
const null_node_index = Node.null_node_index;

const Token = Func.Token;
const TokenType = Token.TokenType;
const CharIndex = Token.CharIndex;
const TokenIndex = Token.TokenIndex;
const null_char_index = Token.null_char_index;

memory: *Memory,

this_func: Func = undefined,
char_buffer: []const []const u8 = undefined,

pub fn a(memory: *Memory) Parse {
    const self = Parse{
        .memory = memory,
    };
    return self;
}

pub fn d(self: *Parse) void {
    self.* = undefined;
}

pub fn parseFuncSource(self: *Parse, func_path: []const u8, is_main_func: bool) !Func {
    self.this_func = Func.a(self.memory, func_path, is_main_func);
    var memory = Memory.a();
    defer memory.d();
    var file = File.open(&memory, func_path) catch |err| {
        Console.print2("{s}: parseFuncSource: {any}\n", .{ func_path, err });
        return err;
    };
    defer file.d();
    const source_code_buffer = try file.readAll();
    defer memory.free2(source_code_buffer);
    var list = Char.getUtf8CharList(self.memory, source_code_buffer) catch unreachable;
    defer list.d();
    self.char_buffer = list.values();
    try self.getFuncTokenList();
    try self.getFuncCodeList();
    return self.this_func;
}

fn getFuncTokenList(self: *Parse) !void {
    var parser = TokenParse.a(self.memory, self.char_buffer);
    while (parser.index < self.char_buffer.len) {
        const token = parser.next() catch |err| {
            const error_text = TokenParse.getErrorText(err);
            const code_info = try self.getCodeInfo(parser.index);
            Console.print2("{s}:{d}:{d}: error: {s}\n{s}\n", .{
                self.this_func.func_path,
                code_info.line_no,
                code_info.column_no,
                error_text,
                code_info.text,
            });
            return err;
        };
        parser.token_pre = token;
        if (token.end_char != null_char_index) {
            try self.this_func.token_list.add(token);
        }
    }
    if (Config.reserve_token_file) {
        var buffer: [1024000]u8 = undefined;
        var memory = Memory.as(&buffer);
        const token_file_path = try String.concatStr(&memory, &.{ Config.output_tmp_dir_absolute_path, "/", self.this_func.full_name, ".token" });
        var file = try File.create(&memory, token_file_path);
        defer file.d();
        for (self.this_func.token_list.values(), 0..) |token, index| {
            memory.rs();
            const start_and_end = try String.formatStr(&memory, "{d}|{d}", .{ token.start_char, token.end_char });
            var text = try String.concatStr(&memory, &.{ start_and_end, ": ", token.text });
            text = try String.formatStr(&memory, "{s} {d} {any}\n", .{ text, index, token.token_type });
            _ = try file.append(text);
        }
    }
}
fn getFuncCodeList(self: *Parse) !void {
    var parser = CodeParse.a(self.memory, &self.this_func);
    while (parser.index < self.this_func.token_list.values().len) {
        const func_code = parser.next(null) catch |err| {
            const error_text = CodeParse.getErrorText(err);
            const error_token = parser.tokens[parser.error_func_code.?.end_token];
            const code_info = try self.getCodeInfo(error_token.end_char);
            Console.print2("{s}:{d}:{d}: error: {s}\n{s}\n", .{
                self.this_func.func_path,
                code_info.line_no,
                code_info.column_no,
                error_text,
                code_info.text,
            });
            return err;
        };
        try self.this_func.appendCodeList(func_code);
    }
    if (Config.reserve_code_node_file) {
        var memory = Memory.a();
        memory.f();
        defer memory.d();
        const code_node_file_path = try String.concatStr(&memory, &.{ Config.output_tmp_dir_absolute_path, "/", self.this_func.full_name, ".node" });
        var file = try File.create(&memory, code_node_file_path);
        defer file.d();
        for (self.this_func.code_list.values(), 0..) |_code, index| {
            const node = _code.node_map.get(root_node_index);
            if (node != null) {
                var text = try getNodeInfoText(&memory, parser, _code, _code.child_list, node.?, 1);
                text = try String.formatStr(&memory, "[{d}] [code={any}] {s}\n", .{
                    index + 1,
                    _code.code_type,
                    text,
                });
                _ = try file.append(text);
            } else {
                Console.print2(">>>>>>node_map.get null: func_file={s}, code_index={d}, code_type={any}, node_index={d}\n", .{
                    self.this_func.func_path,
                    index,
                    _code.code_type,
                    root_node_index,
                });
            }
        }
    }
}
fn getNodeInfoText(memory: *Memory, parser: CodeParse, _code: Code, child_code_list: ?List.t(Code), node: Node, level: usize) ![]const u8 {
    const main_token = parser.tokens[node.main_token];
    const main_token_info = try String.formatStr(memory, "{s}main_token: {s} {d} {any}", .{
        try getPadArrow(memory, level),
        main_token.text,
        node.main_token,
        main_token.token_type,
    });
    var left_info: []const u8 = undefined;
    if (node.left_side != null_node_index) {
        const left_node = _code.node_map.get(node.left_side);
        const text = try getNodeInfoText(memory, parser, _code, null, left_node.?, level + 1);
        left_info = try String.formatStr(memory, "{s}left_side: {s}", .{
            try getPadArrow(memory, level),
            text,
        });
        if (left_node.?.left_side != null_node_index and (left_node.?.node_type == .fn_arg or left_node.?.node_type == .fn_param or left_node.?.node_type == .case_arg)) {
            const list = _code.arg_node_index_map.get(left_node.?.left_side);
            if (list != null) {
                for (list.?.values(), 0..) |arg_node_index, index| {
                    const arg_node = _code.node_map.get(arg_node_index);
                    var arg_text = try getNodeInfoText(memory, parser, _code, null, arg_node.?, level + 2);
                    arg_text = try String.formatStr(memory, "{s}({d}) arg_node: {s}", .{
                        try getPadArrow(memory, level + 1),
                        index + 1,
                        arg_text,
                    });
                    left_info = try String.concatStr(memory, &.{ left_info, arg_text, "\n" });
                }
            } else {
                const err_node = _code.node_map.get(left_node.?.left_side);
                const err_node_text = try getNodeInfoText(memory, parser, _code, null, err_node.?, level + 1);
                Console.print2(">>>>>>arg_node_index_map.get null: _code.code_type={any}, left_node.?.left_side={d}, err_node_text={s}\n", .{
                    _code.code_type,
                    left_node.?.left_side,
                    err_node_text,
                });
            }
        }
    } else {
        left_info = try String.formatStr(memory, "{s}left_side:", .{
            try getPadArrow(memory, level),
        });
    }
    var right_info: []const u8 = undefined;
    if (node.right_side != null_node_index) {
        const right_node = _code.node_map.get(node.right_side);
        const text = try getNodeInfoText(memory, parser, _code, null, right_node.?, level + 1);
        right_info = try String.formatStr(memory, "{s}right_side: {s}", .{
            try getPadArrow(memory, level),
            text,
        });
        if (right_node.?.right_side != null_node_index and (right_node.?.node_type == .func_init_arg_list or right_node.?.node_type == .container_field or right_node.?.node_type == .func_init_dot)) {
            const list = _code.arg_node_index_map.get(right_node.?.right_side);
            if (list != null) {
                for (list.?.values(), 0..) |arg_node_index, index| {
                    const arg_node = _code.node_map.get(arg_node_index);
                    var arg_text = try getNodeInfoText(memory, parser, _code, null, arg_node.?, level + 2);
                    arg_text = try String.formatStr(memory, "{s}({d}) arg_node: {s}", .{
                        try getPadArrow(memory, level + 1),
                        index + 1,
                        arg_text,
                    });
                    right_info = try String.concatStr(memory, &.{ right_info, arg_text, "\n" });
                }
            } else {
                const err_node = _code.node_map.get(right_node.?.right_side);
                const err_node_text = try getNodeInfoText(memory, parser, _code, null, err_node.?, level + 1);
                Console.print2(">>>>>>arg_node_index_map.get null: _code.code_type={any}, right_node.?.right_side={d}, err_node_text={s}\n", .{
                    _code.code_type,
                    right_node.?.right_side,
                    err_node_text,
                });
            }
        }
    } else {
        right_info = try String.formatStr(memory, "{s}right_side:", .{
            try getPadArrow(memory, level),
        });
    }
    var node_name: []const u8 = undefined;
    if (level == 1) {
        node_name = "root-node";
    } else {
        node_name = "node";
    }
    var text = try String.formatStr(memory, "{s}={any}:\n{s}\n{s}\n{s}\n", .{
        node_name,
        node.node_type,
        main_token_info,
        left_info,
        right_info,
    });
    if (child_code_list != null) {
        for (child_code_list.?.values(), 0..) |child_code, child_index| {
            const child_code_node = child_code.node_map.get(root_node_index);
            var child_text = try getNodeInfoText(memory, parser, child_code, child_code.child_list, child_code_node.?, level + 1);
            child_text = try String.formatStr(memory, "{s}[code={any}, level={d}] [{d}] [child-code={any}] {s}\n", .{
                try getPadArrow(memory, level),
                _code.code_type,
                level,
                child_index + 1,
                child_code.code_type,
                child_text,
            });
            text = try String.concatStr(memory, &.{ text, child_text });
        }
    }
    return text;
}
fn getPadArrow(memory: *Memory, level: usize) ![]const u8 {
    var padding: []const u8 = "";
    var count: usize = 0;
    while (count < level) {
        padding = try String.concatStr(memory, &.{ padding, "├── " });
        count += 1;
    }
    return padding;
}
fn getCodeInfo(self: *Parse, char_index: CharIndex) !CodeInfo {
    var line_no: usize = 1;
    var column_no: usize = 1;
    var text: []const u8 = "";
    for (self.char_buffer, 0..) |utf8_char, index| {
        text = try String.concatStr(self.memory, &.{ text, utf8_char });
        if (index == char_index - 1) {
            break;
        }
        column_no += 1;
        if (String.equalStr(utf8_char, "\n")) {
            line_no += 1;
            column_no = 0;
            text = "";
        }
    }
    return CodeInfo{
        .line_no = line_no,
        .column_no = column_no,
        .text = try String.copyStr(self.memory, text),
    };
}
const CodeInfo = struct {
    line_no: usize,
    column_no: usize,
    text: []const u8,
};

const Parse = @This();
