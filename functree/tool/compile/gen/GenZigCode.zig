const System = @import("../../System.zig");
const Memory = System.Memory;
const Io = System.Io;
const Console = Io.Console;
const Fs = System.Fs;
const File = Fs.File;
const DataType = System.DataType;
const String = DataType.String;
const List = DataType.List;
const Map = DataType.Map;
const StringMap = DataType.StringMap;

const Func = @import("../Func.zig");
const Code = Func.Code;

const Node = Func.Node;
const NodeType = Node.NodeType;
const NodeIndex = Node.NodeIndex;
const root_node_index = Node.root_node_index;
const null_node_index = Node.null_node_index;

const Token = Func.Token;
const TokenType = Token.TokenType;
const TokenIndex = Token.TokenIndex;

const TargetCode = @import("TargetCode.zig");
const Gen = @import("../Gen.zig");
const GenError = Gen.GenError;

memory: *Memory,
this_func: Func,
tokens: []Token,
target_code_list: List.t(TargetCode),

prefix_space: []const u8 = "",
array_type_info: ?ArrayTypeInfo = null,
array_level: usize = 0,
if_else_flag_map: ?Map.t(usize, bool) = null,

pub fn a(memory: *Memory, this_func: Func) GenZigCode {
    const self = GenZigCode{
        .memory = memory,
        .this_func = this_func,
        .tokens = this_func.token_list.values(),
        .target_code_list = List.t(TargetCode).a(memory),
    };
    return self;
}
pub fn d(self: *GenZigCode) void {
    self.* = undefined;
}

pub fn genTargetCodeList(self: *GenZigCode) !List.t(TargetCode) {
    var i: usize = 0;
    while (i < self.this_func.code_list.values().len) {
        const source_code = self.this_func.code_list.values()[i];
        if (self.if_else_flag_map != null) {
            self.if_else_flag_map.?.d();
            self.if_else_flag_map = null;
        }
        self.if_else_flag_map = Map.t(usize, bool).a(self.memory);
        if (i < self.this_func.code_list.values().len - 1) {
            const next_code = self.this_func.code_list.values()[i + 1];
            if ((source_code.code_type == .if_block or source_code.code_type == .else_block or source_code.code_type == .else_if_block) and (next_code.code_type == .else_block or next_code.code_type == .else_if_block)) {
                try self.if_else_flag_map.?.add(0, true);
            } else {
                try self.if_else_flag_map.?.add(0, false);
            }
        } else {
            try self.if_else_flag_map.?.add(0, false);
        }
        var target_code = TargetCode.a(self.memory);
        const code_line = try self.genTargetCodeText(source_code, 0);
        try target_code.appendCodeLineList(code_line);
        try self.target_code_list.add(target_code);
        i += 1;
    }
    var func_name: []const u8 = self.this_func.full_name;
    const last_period_pos = String.lastIndexOfStr(func_name, ".");
    if (last_period_pos != null) {
        func_name = func_name[last_period_pos.? + 1 ..];
    }
    const code_line = try String.concatStr(self.memory, &.{ "\nconst ", func_name, "=@This();" });
    var target_code = TargetCode.a(self.memory);
    try target_code.appendCodeLineList(code_line);
    try self.target_code_list.add(target_code);
    return self.target_code_list;
}

fn genTargetCodeText(self: *GenZigCode, source_code: Code, level: usize) anyerror![]const u8 {
    const prefix_space = try self.getPrefixSpace(level);
    switch (source_code.code_type) {
        .declare_param => {
            return try self.generateParamCode(source_code, level);
        },
        .define_var => {
            return try self.generateVarCode(source_code, level);
        },
        .assign => {
            return try self.generateAssignCode(source_code, level);
        },
        .call_fn => {
            return try self.generateCallFnCode(source_code, level);
        },
        ._break => {
            return try String.concatStr(self.memory, &.{ prefix_space, "break;\n" });
        },
        ._continue => {
            return try String.concatStr(self.memory, &.{ prefix_space, "continue;\n" });
        },
        ._unreachable => {
            return try String.concatStr(self.memory, &.{ prefix_space, "unreachable;\n" });
        },
        ._return => {
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, "return" });
            const root_node = try source_code.getNode(root_node_index);
            if (root_node.right_side != null_node_index) {
                const result = try self.generateExpressionText(source_code, root_node.right_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, " ", result });
            }
            code_line = try String.concatStr(self.memory, &.{ code_line, ";\n" });
            return code_line;
        },
        ._asm => {
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, "asm (" });
            const root_node = try source_code.getNode(root_node_index);
            const result = try self.generateExpressionText(source_code, root_node.right_side);
            code_line = try String.concatStr(self.memory, &.{ code_line, prefix_space, result });
            code_line = try String.concatStr(self.memory, &.{ code_line, prefix_space, ");\n" });
            return code_line;
        },
        ._code => {
            const root_node = try source_code.getNode(root_node_index);
            const right_node = try source_code.getNode(root_node.right_side);
            var main_text = self.tokens[right_node.main_token].text;
            main_text = try String.replaceStr(self.memory, main_text, "'''", "");
            const code_line = try String.concatStr(self.memory, &.{ prefix_space, main_text, "\n" });
            return code_line;
        },
        ._try => {
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, "try " });
            const root_node = try source_code.getNode(root_node_index);
            const text = try self.generateExpressionText(source_code, root_node.right_side);
            code_line = try String.concatStr(self.memory, &.{ code_line, text, ";\n" });
            return code_line;
        },
        ._include => {
            const root_node = try source_code.getNode(root_node_index);
            var relative_path = try self.generateExpressionText(source_code, root_node.right_side);
            relative_path = relative_path[1 .. relative_path.len - 1];
            for (self.this_func.depend_func_list.values()) |depend_func| {
                if (String.equalStr(depend_func.import_path, relative_path)) {
                    relative_path = depend_func.func_path;
                    break;
                }
            }

            var file = File.open(self.memory, relative_path) catch |err| {
                Console.print2("{s}: read file error: {any}\n", .{ relative_path, err });
                return GenError.open_include_file_fail;
            };
            defer file.d();
            return try file.readAll();
        },
        .define_fn => {
            var code_line = prefix_space;
            const root_node = try source_code.getNode(root_node_index);
            if (root_node.left_side != null_node_index) {
                const text = try self.generateIdentifierText(source_code, root_node.left_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, text, " fn " });
            } else {
                code_line = try String.concatStr(self.memory, &.{ code_line, "fn " });
            }
            const fn_proto_node = try source_code.getNode(root_node.right_side);
            const fn_name = self.generateCodeByTokenIndex(fn_proto_node.main_token);
            code_line = try String.concatStr(self.memory, &.{ code_line, fn_name, "(" });
            const fn_param_node = try source_code.getNode(fn_proto_node.left_side);
            const param_node_start = fn_param_node.left_side;
            if (param_node_start != null_node_index) {
                const arg_node_index_list = source_code.arg_node_index_map.get(param_node_start);
                for (arg_node_index_list.?.values()) |param_node_index| {
                    const param_node_text = try self.generateIdentifierAndTypeText(source_code, param_node_index);
                    if (param_node_index == param_node_start) {
                        code_line = try String.concatStr(self.memory, &.{ code_line, param_node_text });
                    } else {
                        code_line = try String.concatStr(self.memory, &.{ code_line, ", ", param_node_text });
                    }
                }
            }
            code_line = try String.concatStr(self.memory, &.{ code_line, ") " });
            const result_text = try self.generateExpressionText(source_code, fn_proto_node.right_side);
            const fn_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ code_line, result_text, " {\n", fn_body_text });
            return code_line;
        },
        ._block => {
            var code_line = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ prefix_space, "{\n", code_line });
            return code_line;
        },
        .if_block => {
            const root_node = try source_code.getNode(root_node_index);
            const main_token = self.tokens[root_node.main_token];
            const condition_node = try source_code.getNode(root_node.left_side);
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, main_token.text, " (" });
            if (condition_node.node_type == .if_block) {
                const item_text = try self.generateExpressionText(source_code, condition_node.left_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, item_text, ") |" });
                const value_text = try self.generateExpressionText(source_code, condition_node.right_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, value_text, "|" });
            } else {
                const condition = try self.generateExpressionText(source_code, root_node.left_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, condition, ")" });
            }
            const right_side = root_node.right_side;
            if (right_side != null_node_index) {
                const right_node = try source_code.getNode(right_side);
                var if_body_text: []const u8 = undefined;
                switch (right_node.node_type) {
                    ._break => if_body_text = "break",
                    ._continue => if_body_text = "continue",
                    ._unreachable => if_body_text = "unreachable",
                    ._return => {
                        if (right_side != null_node_index) {
                            if_body_text = try self.generateExpressionText(source_code, right_side);
                        } else {
                            if_body_text = "return";
                        }
                    },
                    .assign => {
                        if_body_text = try self.generateAssignText(source_code, right_side);
                    },
                    else => {
                        if_body_text = try self.generateExpressionText(source_code, right_side);
                    },
                }
                if (right_node.node_type == .empty_block) {
                    code_line = try String.concatStr(self.memory, &.{ code_line, " ", if_body_text });
                } else {
                    code_line = try String.concatStr(self.memory, &.{ code_line, " ", if_body_text, ";\n" });
                }
            } else {
                const if_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
                code_line = try String.concatStr(self.memory, &.{ code_line, " {\n", if_body_text });
            }
            return code_line;
        },
        .else_block => {
            const root_node = try source_code.getNode(root_node_index);
            const main_token = self.tokens[root_node.main_token];
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, "} ", main_token.text, " " });
            code_line = try String.concatStr(self.memory, &.{ code_line, "{\n" });
            const else_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ code_line, else_body_text });
            return code_line;
        },
        .else_if_block => {
            const root_node = try source_code.getNode(root_node_index);
            const main_token = self.tokens[root_node.main_token];
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, "} ", main_token.text, " " });
            const if_node_index = root_node.right_side;
            code_line = try String.concatStr(self.memory, &.{ code_line, "if (" });
            const if_node = try source_code.getNode(if_node_index);
            const condition_node_index = if_node.right_side;
            const condition = try self.generateExpressionText(source_code, condition_node_index);
            code_line = try String.concatStr(self.memory, &.{ code_line, condition, ") {\n" });
            const else_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ code_line, else_body_text });
            return code_line;
        },
        .switch_block => {
            const root_node = try source_code.getNode(root_node_index);
            var code_line = try self.generateSwitchCodeLine(source_code, root_node);
            const switch_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ code_line, switch_body_text });
            return code_line;
        },
        .switch_case_block => {
            const root_node = try source_code.getNode(root_node_index);
            var code_line: []const u8 = prefix_space;
            const case_node_index = root_node.left_side;
            const case_node = try source_code.getNode(case_node_index);
            const case_arg_start = case_node.left_side;
            if (case_arg_start != null_node_index) {
                const arg_node_index_list = source_code.arg_node_index_map.get(case_arg_start);
                for (arg_node_index_list.?.values()) |arg_node_index| {
                    const arg_node_text = try self.generateExpressionText(source_code, arg_node_index);
                    if (arg_node_index == case_arg_start) {
                        code_line = try String.concatStr(self.memory, &.{ code_line, arg_node_text });
                    } else {
                        code_line = try String.concatStr(self.memory, &.{ code_line, ", ", arg_node_text });
                    }
                }
            }
            code_line = try String.concatStr(self.memory, &.{ code_line, " => " });
            const right_side = root_node.right_side;
            if (right_side != null_node_index) {
                const right_node = try source_code.getNode(right_side);
                switch (right_node.node_type) {
                    .if_block => {
                        code_line = try String.concatStr(self.memory, &.{ code_line, "if (" });
                        const condition_node_index = right_node.right_side;
                        const condition = try self.generateExpressionText(source_code, condition_node_index);
                        code_line = try String.concatStr(self.memory, &.{ code_line, condition, ") {\n" });
                        const if_body_text = try self.generateChildCodeText2(source_code, level + 1, prefix_space);
                        code_line = try String.concatStr(self.memory, &.{ code_line, if_body_text });
                    },
                    .while_block => {
                        code_line = try String.concatStr(self.memory, &.{ code_line, "while (" });
                        const condition_node_index = right_node.right_side;
                        const condition = try self.generateExpressionText(source_code, condition_node_index);
                        code_line = try String.concatStr(self.memory, &.{ code_line, condition, ") {\n" });
                        const while_body_text = try self.generateChildCodeText2(source_code, level + 1, prefix_space);
                        code_line = try String.concatStr(self.memory, &.{ code_line, while_body_text });
                    },
                    .switch_block => {
                        code_line = try String.concatStr(self.memory, &.{ code_line, "switch (" });
                        const condition_node_index = right_node.right_side;
                        const condition = try self.generateExpressionText(source_code, condition_node_index);
                        code_line = try String.concatStr(self.memory, &.{ code_line, condition, ") {\n" });
                        const switch_body_text = try self.generateChildCodeText2(source_code, level + 1, prefix_space);
                        code_line = try String.concatStr(self.memory, &.{ code_line, switch_body_text });
                    },
                    .empty_block => {
                        code_line = try String.concatStr(self.memory, &.{ code_line, "{},\n" });
                    },
                    ._break => code_line = try String.concatStr(self.memory, &.{ code_line, "break,\n" }),
                    ._continue => code_line = try String.concatStr(self.memory, &.{ code_line, "continue,\n" }),
                    ._unreachable => code_line = try String.concatStr(self.memory, &.{ code_line, "unreachable,\n" }),
                    ._return => {
                        if (right_side != null_node_index) {
                            const right_text = try self.generateExpressionText(source_code, right_side);
                            code_line = try String.concatStr(self.memory, &.{ code_line, right_text, ",\n" });
                        } else {
                            code_line = try String.concatStr(self.memory, &.{ code_line, "return,\n" });
                        }
                    },
                    ._try => {
                        const right_text = try self.generateExpressionText(source_code, right_side);
                        code_line = try String.concatStr(self.memory, &.{ code_line, right_text, ",\n" });
                    },
                    .assign => {
                        const right_text = try self.generateAssignText(source_code, right_side);
                        code_line = try String.concatStr(self.memory, &.{ code_line, right_text, ",\n" });
                    },
                    else => {
                        const text = try self.generateExpressionText(source_code, right_side);
                        code_line = try String.concatStr(self.memory, &.{ code_line, text, ",\n" });
                    },
                }
            } else {
                code_line = try String.concatStr(self.memory, &.{ code_line, "{\n" });
                const case_body_text = try self.generateChildCodeText2(source_code, level + 1, prefix_space);
                code_line = try String.concatStr(self.memory, &.{ code_line, case_body_text });
            }
            return code_line;
        },
        .test_block => {
            const root_node = try source_code.getNode(root_node_index);
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, "test " });
            if (root_node.right_side != null_node_index) {
                const test_name = try self.generateExpressionText(source_code, root_node.right_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, test_name, " {\n" });
            } else {
                code_line = try String.concatStr(self.memory, &.{ code_line, "{\n" });
            }
            const test_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ code_line, test_body_text });
            return code_line;
        },
        ._defer, ._errdefer, ._comptime => {
            const root_node = try source_code.getNode(root_node_index);
            const main_token = self.tokens[root_node.main_token];
            var code_line = try String.concatStr(self.memory, &.{ prefix_space, main_token.text, " " });
            if (root_node.right_side != null_node_index) {
                const test_name = try self.generateExpressionText(source_code, root_node.right_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, test_name, ";\n" });
            } else {
                code_line = try String.concatStr(self.memory, &.{ code_line, "{\n" });
                const defer_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
                code_line = try String.concatStr(self.memory, &.{ code_line, defer_body_text });
            }
            return code_line;
        },
        .for_block => {
            const root_node = try source_code.getNode(root_node_index);
            var code_line: []const u8 = prefix_space;
            if (source_code.is_inline) {
                code_line = try String.concatStr(self.memory, &.{ code_line, "inline " });
            }
            code_line = try String.concatStr(self.memory, &.{ code_line, "for (" });
            const condition_node = try source_code.getNode(root_node.left_side);
            const condition_item_node = try source_code.getNode(condition_node.left_side);
            const condition_item_text = try self.generateFnArgText(source_code, condition_item_node.left_side);
            const condition_value_node = try source_code.getNode(condition_node.right_side);
            const condition_value_text = try self.generateFnArgText(source_code, condition_value_node.left_side);
            code_line = try String.concatStr(self.memory, &.{ code_line, condition_item_text, ") |", condition_value_text, "| " });
            if (source_code.child_list.count() > 0) {
                code_line = try String.concatStr(self.memory, &.{ code_line, "{\n " });
                const for_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
                code_line = try String.concatStr(self.memory, &.{ code_line, for_body_text });
            } else {
                const for_body_text = try self.generateExpressionText(source_code, root_node.right_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, for_body_text, ";" });
            }
            return code_line;
        },
        .while_block => {
            const root_node = try source_code.getNode(root_node_index);
            var code_line: []const u8 = prefix_space;
            if (source_code.is_inline) {
                code_line = try String.concatStr(self.memory, &.{ code_line, "inline " });
            }
            if (root_node.left_side == null_node_index) {
                code_line = try String.concatStr(self.memory, &.{ code_line, "while (" });
                const condition_node_index = root_node.right_side;
                const condition = try self.generateExpressionText(source_code, condition_node_index);
                code_line = try String.concatStr(self.memory, &.{ code_line, condition, ") {\n" });
            } else {
                code_line = try String.concatStr(self.memory, &.{ code_line, "while (" });
                const item_text = try self.generateExpressionText(source_code, root_node.left_side);
                const items_text = try self.generateExpressionText(source_code, root_node.right_side);
                code_line = try String.concatStr(self.memory, &.{ code_line, items_text, ") |", item_text, "| {\n" });
            }
            const while_body_text = try self.generateChildCodeText(source_code, level + 1, prefix_space);
            code_line = try String.concatStr(self.memory, &.{ code_line, while_body_text });
            return code_line;
        },
        else => {
            Console.print2("GenZigCode genTargetCodeText error: unkown source code type '{any}': ", .{
                source_code.code_type,
            });
            return GenError.invalid_code_type;
        },
    }
}

fn generateChildCodeText(self: *GenZigCode, source_code: Code, level: usize, prefix_space: []const u8) ![]const u8 {
    var code_line: []const u8 = "";
    var i: usize = 0;
    while (i < source_code.child_list.values().len) {
        const child_code = source_code.child_list.values()[i];
        if (i < source_code.child_list.values().len - 1) {
            const next_code = source_code.child_list.values()[i + 1];
            if ((child_code.code_type == .if_block or child_code.code_type == .else_block or child_code.code_type == .else_if_block) and (next_code.code_type == .else_block or next_code.code_type == .else_if_block)) {
                try self.if_else_flag_map.?.add(level, true);
            } else {
                try self.if_else_flag_map.?.add(level, false);
            }
        } else {
            try self.if_else_flag_map.?.add(level, false);
        }
        const child_text = try self.genTargetCodeText(child_code, level);
        code_line = try String.concatStr(self.memory, &.{ code_line, child_text });
        i += 1;
    }
    if (self.if_else_flag_map.?.get(level - 1) != true) {
        code_line = try String.concatStr(self.memory, &.{ code_line, prefix_space, "}\n" });
    }
    return code_line;
}

fn generateChildCodeText2(self: *GenZigCode, source_code: Code, level: usize, prefix_space: []const u8) ![]const u8 {
    var code_line: []const u8 = "";
    var i: usize = 0;
    while (i < source_code.child_list.values().len) {
        const child_code = source_code.child_list.values()[i];
        if (i < source_code.child_list.values().len - 1) {
            const next_code = source_code.child_list.values()[i + 1];
            if ((child_code.code_type == .if_block or child_code.code_type == .else_block or child_code.code_type == .else_if_block) and (next_code.code_type == .else_block or next_code.code_type == .else_if_block)) {
                try self.if_else_flag_map.?.add(level, true);
            } else {
                try self.if_else_flag_map.?.add(level, false);
            }
        } else {
            try self.if_else_flag_map.?.add(level, false);
        }
        const child_text = try self.genTargetCodeText(child_code, level);
        code_line = try String.concatStr(self.memory, &.{ code_line, child_text });
        i += 1;
    }
    code_line = try String.concatStr(self.memory, &.{ code_line, prefix_space, "},\n" });
    return code_line;
}

fn getPrefixSpace(self: *GenZigCode, level: usize) ![]const u8 {
    var prefix_space: []const u8 = "";
    var count: usize = 0;
    while (count < level) {
        prefix_space = try String.concatStr(self.memory, &.{ prefix_space, "  " });
        count += 1;
    }
    self.prefix_space = prefix_space;
    return prefix_space;
}
fn generateParamCode(self: *GenZigCode, source_code: Code, level: usize) ![]const u8 {
    var code_line: []const u8 = try self.getPrefixSpace(level);
    const root_node = try source_code.getNode(root_node_index);
    var text: []const u8 = "";
    if (root_node.node_type == .assign) {
        text = try self.generateAssignText(source_code, root_node_index);
    } else {
        text = try self.generateIdentifierAndTypeText(source_code, root_node_index);
    }
    code_line = try String.concatStr(self.memory, &.{ code_line, text, ",\n" });
    return code_line;
}
fn generateVarCode(self: *GenZigCode, source_code: Code, level: usize) ![]const u8 {
    var code_line: []const u8 = try self.getPrefixSpace(level);
    const root_node = try source_code.getNode(root_node_index);
    if (root_node.left_side != null_node_index) {
        const text = try self.generateIdentifierAndTypeText(source_code, root_node.left_side);
        code_line = try String.concatStr(self.memory, &.{ code_line, text, " " });
    }
    const token_text = self.generateCodeByTokenIndex(root_node.main_token);
    code_line = try String.concatStr(self.memory, &.{ code_line, token_text, " " });
    const right_side = root_node.right_side;
    const right_node = try source_code.getNode(right_side);
    const right_token_index = right_node.main_token;
    const right_token = self.tokens[right_token_index];
    if (right_token.token_type == .equal) {
        const text = try self.generateAssignText(source_code, right_side);
        code_line = try String.concatStr(self.memory, &.{ code_line, text, ";\n" });
    } else {
        const text = try self.generateExpressionText(source_code, right_side);
        code_line = try String.concatStr(self.memory, &.{ code_line, text, ";\n" });
    }
    return code_line;
}

fn generateAssignCode(self: *GenZigCode, source_code: Code, level: usize) ![]const u8 {
    var code_line: []const u8 = try self.getPrefixSpace(level);
    const text = try self.generateAssignText(source_code, root_node_index);
    code_line = try String.concatStr(self.memory, &.{ code_line, text, ";\n" });
    return code_line;
}
fn generateCallFnCode(self: *GenZigCode, source_code: Code, level: usize) ![]const u8 {
    var code_line: []const u8 = try self.getPrefixSpace(level);
    const text = try self.generateExpressionText(source_code, root_node_index);
    code_line = try String.concatStr(self.memory, &.{ code_line, text, ";\n" });
    return code_line;
}
fn generateSwitchCodeLine(self: *GenZigCode, source_code: Code, switch_node: Node) ![]const u8 {
    const code_line = try String.concatStr(self.memory, &.{ self.prefix_space, "switch (" });
    const condition = try self.generateExpressionText(source_code, switch_node.right_side);
    return try String.concatStr(self.memory, &.{ code_line, condition, ") {\n" });
}

fn generateAssignText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const equal_node = try source_code.getNode(node_index);
    const left_side = equal_node.left_side;
    var text = try self.generateIdentifierAndTypeText(source_code, left_side);
    const main_token = self.tokens[equal_node.main_token];
    text = try String.concatStr(self.memory, &.{ text, " ", main_token.text, " " });
    const right_text = try self.generateExpressionText(source_code, equal_node.right_side);
    text = try String.concatStr(self.memory, &.{ text, right_text });
    return text;
}

fn generateFnArgText(self: *GenZigCode, source_code: Code, arg_node_start: NodeIndex) ![]const u8 {
    var text: []const u8 = "";
    self.array_type_info = null;
    const arg_node_index_list = source_code.arg_node_index_map.get(arg_node_start);
    for (arg_node_index_list.?.values()) |arg_node_index| {
        const arg_node_text = try self.generateExpressionText(source_code, arg_node_index);
        if (arg_node_index == arg_node_start) {
            text = try String.concatStr(self.memory, &.{arg_node_text});
        } else {
            text = try String.concatStr(self.memory, &.{ text, ", ", arg_node_text });
        }
    }
    return text;
}
fn generateExpressionText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) anyerror![]const u8 {
    const this_node = try source_code.getNode(node_index);
    const left_side = this_node.left_side;
    const right_side = this_node.right_side;
    var text: []const u8 = "";
    switch (this_node.node_type) {
        .if_else_line => {
            text = try String.concatStr(self.memory, &.{ text, "if (" });
            const left_node = try source_code.getNode(left_side);
            const condition_text = try self.generateExpressionText(source_code, left_node.left_side);
            const if_value_text = try self.generateExpressionText(source_code, left_node.right_side);
            text = try String.concatStr(self.memory, &.{ text, condition_text, ") ", if_value_text });
            const else_value_text = try self.generateExpressionText(source_code, right_side);
            text = try String.concatStr(self.memory, &.{ text, " else ", else_value_text });
        },
        .func_init => {
            text = try self.generateFuncInitText(source_code, node_index);
        },
        .container_decl => {
            text = try self.generateContainerDeclareText(source_code, node_index);
        },
        .grouped_expression => {
            text = self.generateCodeByTokenIndex(this_node.main_token);
            const left_text = try self.generateExpressionText(source_code, left_side);
            text = try String.concatStr(self.memory, &.{ text, left_text });
            const right_node = try source_code.getNode(right_side);
            const token_index = right_node.main_token;
            const right_text = self.generateCodeByTokenIndex(token_index);
            text = try String.concatStr(self.memory, &.{ text, right_text });
        },
        .call_fn => {
            text = try self.generateExpressionText(source_code, left_side);
            const l_paren_text = self.generateCodeByTokenIndex(this_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, l_paren_text });
            const right_node = try source_code.getNode(right_side);
            if (right_node.left_side != null_node_index) {
                const arg_text = try self.generateFnArgText(source_code, right_node.left_side);
                text = try String.concatStr(self.memory, &.{ text, arg_text });
            }
            const r_paren_text = self.generateCodeByTokenIndex(right_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, r_paren_text });
        },
        .import_func => {
            const import_text = self.generateCodeByTokenIndex(this_node.main_token);
            text = try String.concatStr(self.memory, &.{ "@", import_text, "(" });
            var arg_text = try self.generateExpressionText(source_code, right_side);
            if (self.this_func.is_main_func) {
                var depend_func_path: []const u8 = undefined;
                for (self.this_func.depend_func_list.values()) |depend_func| {
                    if (String.equalStr(depend_func.import_path, arg_text)) {
                        depend_func_path = depend_func.func_path;
                        break;
                    }
                }
                arg_text = try String.concatStr(self.memory, &.{ "\"", depend_func_path, "\"" });
            }
            arg_text = try String.replaceStr(self.memory, arg_text, ".func", ".zig");
            text = try String.concatStr(self.memory, &.{ text, arg_text, ")" });
        },
        ._catch => {
            text = try self.generateExpressionText(source_code, left_side);
            const catch_text = self.generateCodeByTokenIndex(this_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, " ", catch_text });
            var right_text: []const u8 = "";
            if (right_side == null_node_index) {
                right_text = " {\n";
                for (source_code.child_list.values()) |child_code| {
                    const child_text = try self.genTargetCodeText(child_code, 1);
                    right_text = try String.concatStr(self.memory, &.{ right_text, child_text });
                }
                right_text = try String.concatStr(self.memory, &.{ right_text, "}" });
            } else {
                const right_node = try source_code.getNode(right_side);
                if (right_node.node_type == .catch_body) {
                    const catch_arg = try self.generateIdentifierText(source_code, right_node.left_side);
                    right_text = try String.concatStr(self.memory, &.{ " |", catch_arg, "| " });
                    if (right_node.right_side == null_node_index) {
                        right_text = try String.concatStr(self.memory, &.{ right_text, "{\n" });
                        for (source_code.child_list.values()) |child_code| {
                            const child_text = try self.genTargetCodeText(child_code, 1);
                            right_text = try String.concatStr(self.memory, &.{ right_text, child_text });
                        }
                        right_text = try String.concatStr(self.memory, &.{ right_text, "}" });
                    } else {
                        const body_right_node = try source_code.getNode(right_node.right_side);
                        switch (body_right_node.node_type) {
                            ._return => {
                                right_text = try String.concatStr(self.memory, &.{ right_text, "return " });
                                const condition = try self.generateExpressionText(source_code, body_right_node.right_side);
                                right_text = try String.concatStr(self.memory, &.{ right_text, condition });
                            },
                            .call_fn => {
                                const right_text2 = try self.generateExpressionText(source_code, right_node.right_side);
                                right_text = try String.concatStr(self.memory, &.{ right_text, right_text2 });
                            },
                            else => {
                                Console.print2("GenZigCode generateExpressionText error: unkown source code type '{any}': ", .{
                                    source_code.code_type,
                                });
                                return GenError.invalid_code_type;
                            },
                        }
                    }
                } else if (right_node.right_side == null_node_index) {
                    right_text = self.generateCodeByTokenIndex(right_node.main_token);
                    right_text = try String.concatStr(self.memory, &.{ " ", right_text });
                } else {
                    const right_text2 = try self.generateExpressionText(source_code, right_side);
                    right_text = try String.concatStr(self.memory, &.{ right_text, " ", right_text2 });
                }
            }
            text = try String.concatStr(self.memory, &.{ text, right_text });
        },
        .array_init => {
            self.array_level = 0;
            text = try self.generateArrayInitText(source_code, node_index, 0);
        },
        .array_type => {
            self.array_level = 0;
            text = try self.generateArrayTypeText(source_code, node_index);
        },
        .error_union => {
            return self.generateErrorUnionTypeText(source_code, node_index);
        },
        .pointer_type => {
            return self.generatePointerTypeText(source_code, node_index);
        },
        .optional_type => {
            return self.generateOptionalTypeText(source_code, node_index);
        },
        .array_access => {
            const left_text = try self.generateExpressionText(source_code, left_side);
            text = try String.concatStr(self.memory, &.{ text, left_text, "[" });
            const right_text = try self.generateArrayAccessRightText(source_code, right_side);
            text = try String.concatStr(self.memory, &.{ text, right_text });
        },
        .deref, .unwrap_optional => {
            if (left_side != null_node_index) {
                text = try self.generateExpressionText(source_code, left_side);
            }
            const main_token_text = self.generateCodeByTokenIndex(this_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, main_token_text });
        },
        .field_access => {
            text = try self.generateFieldAccessCode(source_code, node_index);
        },
        .func_init_dot => {
            const func_init_dot_text = try self.generateFuncInitDotText(source_code, node_index);
            text = try String.concatStr(self.memory, &.{ text, func_init_dot_text });
        },
        .empty_block => {
            text = "{}";
        },
        .align_type, .callconv_type => {
            const align_text = self.generateCodeByTokenIndex(this_node.main_token);
            const arg_text = try self.generateExpressionText(source_code, right_side);
            text = try String.concatStr(self.memory, &.{ text, align_text, "(", arg_text, ")" });
        },
        .fn_type => {
            const fn_text = self.generateCodeByTokenIndex(this_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, " ", fn_text, " (" });
            const fn_param_node = try source_code.getNode(left_side);
            const param_node_start = fn_param_node.left_side;
            if (param_node_start != null_node_index) {
                const arg_node_index_list = source_code.arg_node_index_map.get(param_node_start);
                for (arg_node_index_list.?.values()) |param_node_index| {
                    const param_node_text = try self.generateIdentifierAndTypeText(source_code, param_node_index);
                    if (param_node_index == param_node_start) {
                        text = try String.concatStr(self.memory, &.{ text, param_node_text });
                    } else {
                        text = try String.concatStr(self.memory, &.{ text, ", ", param_node_text });
                    }
                }
            }
            text = try String.concatStr(self.memory, &.{ text, ") " });
            const result_text = try self.generateExpressionText(source_code, right_side);
            text = try String.concatStr(self.memory, &.{ text, result_text });
        },
        .type_expr => {
            const left_text = try self.generateExpressionText(source_code, left_side);
            text = try String.concatStr(self.memory, &.{ text, " ", left_text });
            const right_text = try self.generateExpressionText(source_code, right_side);
            text = try String.concatStr(self.memory, &.{ text, " ", right_text });
        },
        else => {
            if (left_side != null_node_index) {
                const left_text = try self.generateExpressionText(source_code, left_side);
                text = left_text;
            }
            var main_token_text = self.generateCodeByTokenIndex(this_node.main_token);
            if (this_node.node_type == .multiline_string_literal) {
                main_token_text = try String.replaceStr(self.memory, main_token_text, "'''", "");
                const replaceStr = try String.concatStr(self.memory, &.{ "\n", self.prefix_space, "\\\\" });
                main_token_text = try String.replaceStr(self.memory, main_token_text, "\n", replaceStr);
                main_token_text = try String.concatStr(self.memory, &.{ main_token_text, "\n" });
            }
            if (String.equalStr(text, "")) {
                text = main_token_text;
            } else {
                if (this_node.node_type == .switch_range) {
                    text = try String.concatStr(self.memory, &.{ text, main_token_text });
                } else {
                    text = try String.concatStr(self.memory, &.{ text, " ", main_token_text });
                }
            }
            if (right_side != null_node_index) {
                const right_text = try self.generateExpressionText(source_code, right_side);
                switch (this_node.node_type) {
                    .negation, .bool_not, .bit_not, .address_of, .switch_range => {
                        text = try String.concatStr(self.memory, &.{ text, right_text });
                    },
                    else => {
                        text = try String.concatStr(self.memory, &.{ text, " ", right_text });
                    },
                }
            }
        },
    }
    return text;
}

fn generateArrayAccessRightText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    var text: []const u8 = "";
    const this_node = try source_code.getNode(node_index);
    const left_side = this_node.left_side;
    const left_node = try source_code.getNode(left_side);
    if (left_node.node_type == .slice) {
        const left_text = try self.generateExpressionText(source_code, left_node.left_side);
        text = try String.concatStr(self.memory, &.{ text, left_text, ".." });
        if (left_node.right_side != null_node_index) {
            const right_text = try self.generateExpressionText(source_code, left_node.right_side);
            text = try String.concatStr(self.memory, &.{ text, right_text });
        }
    } else {
        const left_text = try self.generateExpressionText(source_code, left_side);
        text = try String.concatStr(self.memory, &.{ text, left_text });
    }
    text = try String.concatStr(self.memory, &.{ text, "]" });
    if (this_node.right_side != null_node_index) {
        const right_node = try source_code.getNode(this_node.right_side);
        const main_token2 = self.tokens[right_node.main_token];
        var right_text2: []const u8 = "";
        if (main_token2.token_type == .l_bracket) {
            text = try String.concatStr(self.memory, &.{ text, "[" });
            right_text2 = try self.generateArrayAccessRightText(source_code, right_node.right_side);
        } else {
            right_text2 = try self.generateExpressionText(source_code, this_node.right_side);
        }
        text = try String.concatStr(self.memory, &.{ text, right_text2 });
    }
    return text;
}
fn generateArrayInitText(self: *GenZigCode, source_code: Code, node_index: NodeIndex, level: usize) ![]const u8 {
    var text: []const u8 = "";
    const this_node = try source_code.getNode(node_index);
    const left_side = this_node.left_side;
    const right_side = this_node.right_side;
    const right_node = try source_code.getNode(right_side);
    if (this_node.node_type == .array_init) {
        const size_info = try self.getArrayInitSizeInfoText(level);
        if (self.array_type_info == null) {
            text = try String.concatStr(self.memory, &.{".{"});
        } else {
            text = try String.concatStr(self.memory, &.{ size_info, self.array_type_info.?.name, "{" });
        }
        if (right_node.node_type == .array_init) {
            const array_init_text = try self.generateArrayInitText(source_code, right_side, level + 1);
            text = try String.concatStr(self.memory, &.{ text, array_init_text });
        } else if (right_node.node_type == .array_init_comma) {
            const left_text = try self.generateArrayInitText(source_code, right_node.left_side, level + 1);
            const right_text = try self.generateArrayInitText(source_code, right_node.right_side, level + 1);
            text = try String.concatStr(self.memory, &.{ text, left_text, ", ", right_text });
        } else if (right_node.node_type == .array_init_value) {
            if (right_node.left_side == null_node_index) {
                const array_init_text = try self.generateArrayInitText(source_code, right_node.right_side, level + 1);
                text = try String.concatStr(self.memory, &.{ text, array_init_text, "}" });
            } else {
                const array_value_start = right_node.left_side;
                if (array_value_start != null_node_index) {
                    const arg_node_index_list = source_code.arg_node_index_map.get(array_value_start);
                    for (arg_node_index_list.?.values()) |array_value_node_index| {
                        const array_value_node_text = try self.generateExpressionText(source_code, array_value_node_index);
                        if (array_value_node_index == array_value_start) {
                            text = try String.concatStr(self.memory, &.{ text, array_value_node_text });
                        } else {
                            text = try String.concatStr(self.memory, &.{ text, ", ", array_value_node_text });
                        }
                    }
                }
                text = try String.concatStr(self.memory, &.{ text, "}" });
            }
        } else {
            Console.print2("<<<<<<<<<<<<<<<<<<<<<=={any}\n", .{right_node});
        }
    } else if (this_node.node_type == .array_init_comma) {
        const left_text = try self.generateArrayInitText(source_code, left_side, level);
        const right_text = try self.generateArrayInitText(source_code, right_side, level);
        text = try String.concatStr(self.memory, &.{ left_text, ", ", right_text });
    } else if (this_node.node_type == .array_init_value) {
        self.array_level += 1;
        const right_text = try self.generateArrayInitText(source_code, right_side, level + 1);
        text = try String.concatStr(self.memory, &.{ right_text, "}" });
    } else {
        Console.print2(",,,,,,,,,,,,,,,,=={any}\n", .{this_node});
    }
    return text;
}
fn getArrayInitSizeInfoText(self: *GenZigCode, level: usize) ![]const u8 {
    var text: []const u8 = "";
    if (self.array_type_info == null) return text;
    var r_bracket_count: usize = 0;
    const size_info = self.array_type_info.?.size_info;
    const array_len = size_info.len;
    const current_level = level - self.array_level;
    for (size_info, 0..) |char, index| {
        if (r_bracket_count >= current_level) {
            const string = &.{char};
            if (index < array_len - 1 and size_info[index + 1] == ']' and char == '[') {
                if (!String.equalStr(size_info[index..], "[]const ")) {
                    text = try String.concatStr(self.memory, &.{ text, string, "_" });
                } else {
                    text = try String.concatStr(self.memory, &.{ text, string });
                }
            } else {
                text = try String.concatStr(self.memory, &.{ text, string });
            }
        }
        if (char == ']') {
            r_bracket_count += 1;
        }
    }
    return text;
}
fn generateArrayTypeSizeText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    var text: []const u8 = "[";
    const this_node = try source_code.getNode(node_index);
    if (this_node.left_side != null_node_index) {
        const left_node = try source_code.getNode(this_node.left_side);
        if (left_node.node_type == .slice_sentinel) {
            var slice_sentinel_left_text: []const u8 = "";
            if (left_node.left_side != null_node_index) {
                slice_sentinel_left_text = try self.generateIdentifierText(source_code, left_node.left_side);
            }
            const slice_sentinel_right_text = try self.generateIdentifierText(source_code, left_node.right_side);
            text = try String.concatStr(self.memory, &.{ text, slice_sentinel_left_text, ":", slice_sentinel_right_text, "]" });
        } else {
            const array_size_token_text = self.generateCodeByTokenIndex(left_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, array_size_token_text, "]" });
        }
    } else {
        text = try String.concatStr(self.memory, &.{ text, "]" });
    }
    if (this_node.right_side != null_node_index) {
        text = try String.concatStr(self.memory, &.{ text, try self.generateArrayTypeSizeText(source_code, this_node.right_side) });
    }
    return text;
}
fn generateFuncInitText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    var text: []const u8 = "";
    const this_node = try source_code.getNode(node_index);
    const func_name = self.generateCodeByTokenIndex(this_node.main_token);
    text = try String.concatStr(self.memory, &.{ text, func_name, " {" });
    const right_side = this_node.right_side;
    const func_arg_node = try source_code.getNode(right_side);
    const arg_node_start = func_arg_node.right_side;
    if (arg_node_start != null_node_index) {
        const prefix_space = try String.concatStr(self.memory, &.{ self.prefix_space, "  " });
        text = try String.concatStr(self.memory, &.{ text, "\n" });
        const field_node_index_list = source_code.arg_node_index_map.get(arg_node_start);
        for (field_node_index_list.?.values()) |arg_node_index| {
            const arg_node_text = try self.generateFuncInitArgText(source_code, arg_node_index);
            text = try String.concatStr(self.memory, &.{ text, prefix_space, arg_node_text, ",\n" });
        }
        text = try String.concatStr(self.memory, &.{ text, self.prefix_space, "}" });
    } else {
        text = try String.concatStr(self.memory, &.{ text, "}" });
    }
    return text;
}
fn generateFuncInitDotText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    var text: []const u8 = "";
    const this_node = try source_code.getNode(node_index);
    text = try String.concatStr(self.memory, &.{ text, ".{" });
    const arg_node_start = this_node.right_side;
    if (arg_node_start != null_node_index) {
        const prefix_space = try String.concatStr(self.memory, &.{ self.prefix_space, "  " });
        text = try String.concatStr(self.memory, &.{ text, "\n" });
        const field_node_index_list = source_code.arg_node_index_map.get(arg_node_start);
        for (field_node_index_list.?.values()) |arg_node_index| {
            const arg_node_text = try self.generateFuncInitArgText(source_code, arg_node_index);
            text = try String.concatStr(self.memory, &.{ text, prefix_space, arg_node_text, ",\n" });
        }
        text = try String.concatStr(self.memory, &.{ text, self.prefix_space, "}" });
    } else {
        text = try String.concatStr(self.memory, &.{ text, "}" });
    }
    return text;
}
fn generateFuncInitArgText(self: *GenZigCode, source_code: Code, arg_node_index: NodeIndex) ![]const u8 {
    const arg_node = try source_code.getNode(arg_node_index);
    if (self.tokens[arg_node.main_token].token_type == .equal) {
        const left_side = arg_node.left_side;
        var text = try self.generateIdentifierAndTypeText(source_code, left_side);
        text = try String.concatStr(self.memory, &.{ text, " = " });
        const right_side = arg_node.right_side;
        const right_text = try self.generateExpressionText(source_code, right_side);
        return try String.concatStr(self.memory, &.{ text, right_text });
    } else {
        return self.generateExpressionText(source_code, arg_node_index);
    }
}
fn generateContainerDeclareText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    var text: []const u8 = "";
    const this_node = try source_code.getNode(node_index);
    var container_name = self.generateCodeByTokenIndex(this_node.main_token);
    if (String.equalStr(container_name, "func")) {
        container_name = "struct";
    }
    text = try String.concatStr(self.memory, &.{ text, container_name });
    const left_side = this_node.left_side;
    if (left_side != null_node_index) {
        text = try String.concatStr(self.memory, &.{ text, "(" });
        const tag_node_text = try self.generateIdentifierAndTypeText(source_code, left_side);
        text = try String.concatStr(self.memory, &.{ text, tag_node_text, ")" });
    }
    const right_side = this_node.right_side;
    const container_field_node = try source_code.getNode(right_side);
    const field_node_start = container_field_node.right_side;
    text = try String.concatStr(self.memory, &.{ text, " {" });
    if (!source_code.is_fn) {
        text = try String.concatStr(self.memory, &.{ text, "\n" });
    }
    if (field_node_start != null_node_index) {
        const prefix_space = try String.concatStr(self.memory, &.{ self.prefix_space, "  " });
        const field_node_index_list = source_code.arg_node_index_map.get(field_node_start);
        var count: usize = 0;
        for (field_node_index_list.?.values(), 0..) |field_node_index, index| {
            const field_node = try source_code.getNode(field_node_index);
            var field_node_text: []const u8 = undefined;
            if (field_node.node_type == .func_init_arg) {
                field_node_text = try self.generateAssignText(source_code, field_node_index);
            } else {
                field_node_text = try self.generateIdentifierAndTypeText(source_code, field_node_index);
            }
            text = try String.concatStr(self.memory, &.{ text, prefix_space, field_node_text });
            if (!source_code.is_fn) {
                text = try String.concatStr(self.memory, &.{ text, ",\n" });
            } else {
                if (index < field_node_index_list.?.values().len - 1) {
                    text = try String.concatStr(self.memory, &.{ text, "," });
                }
            }
            count += 1;
        }
        text = try String.concatStr(self.memory, &.{ text, self.prefix_space, "}" });
    } else {
        text = try String.concatStr(self.memory, &.{ text, "}" });
    }
    return text;
}
fn generateIdentifierAndTypeText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    switch (this_node.node_type) {
        .identifier => {
            return self.generateIdentifierText(source_code, node_index);
        },
        .field_access => {
            return self.generateFieldAccessCode(source_code, node_index);
        },
        .array_type => {
            return self.generateArrayTypeText(source_code, node_index);
        },
        .array_access => {
            return self.generateExpressionText(source_code, node_index);
        },
        .deref => {
            var text: []const u8 = "";
            if (this_node.left_side != null_node_index) {
                text = try self.generateExpressionText(source_code, this_node.left_side);
            }
            const main_token_text = self.generateCodeByTokenIndex(this_node.main_token);
            text = try String.concatStr(self.memory, &.{ text, main_token_text });
            return text;
        },
        .type_decl => {
            var text = try self.generateExpressionText(source_code, this_node.left_side);
            if (this_node.right_side != null_node_index) {
                const node_text = try self.generateExpressionText(source_code, this_node.right_side);
                if (!source_code.is_array_init) {
                    text = try String.concatStr(self.memory, &.{ text, ": ", node_text });
                }
            }
            return text;
        },
        ._comptime => {
            var text = self.generateCodeByTokenIndex(this_node.main_token);
            if (this_node.right_side != null_node_index) {
                const node_text = try self.generateIdentifierAndTypeText(source_code, this_node.right_side);
                text = try String.concatStr(self.memory, &.{ text, " ", node_text });
            }
            return text;
        },
        .error_union => {
            return self.generateErrorUnionTypeText(source_code, node_index);
        },
        .pointer_type => {
            return self.generatePointerTypeText(source_code, node_index);
        },
        .optional_type => {
            return self.generateOptionalTypeText(source_code, node_index);
        },
        else => {
            Console.print2("GenZigCode generateIdentifierAndTypeText error: unkown source code type '{any}': ", .{source_code.code_type});
            return GenError.invalid_code_type;
        },
    }
}
fn generateIdentifierText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    var text: []const u8 = self.generateCodeByTokenIndex(this_node.main_token);
    if (this_node.left_side != null_node_index) {
        const left_text = try self.generateIdentifierAndTypeText(source_code, this_node.left_side);
        text = try String.concatStr(self.memory, &.{ left_text, " ", text });
    }
    if (this_node.right_side != null_node_index) {
        const right_text = try self.generateIdentifierAndTypeText(source_code, this_node.right_side);
        text = try String.concatStr(self.memory, &.{ text, " ", right_text });
    }
    return text;
}
fn generateFieldAccessCode(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    var text: []const u8 = "";
    const left_side = this_node.left_side;
    if (left_side != null_node_index) {
        const left_text = try self.generateExpressionText(source_code, left_side);
        text = try String.concatStr(self.memory, &.{ text, left_text });
    }
    const main_token_text = self.generateCodeByTokenIndex(this_node.main_token);
    text = try String.concatStr(self.memory, &.{ text, main_token_text });
    const right_side = this_node.right_side;
    if (right_side != null_node_index) {
        const right_token_text = try self.generateExpressionText(source_code, right_side);
        text = try String.concatStr(self.memory, &.{ text, right_token_text });
    }
    return text;
}
fn generateArrayTypeText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    const left_side = this_node.left_side;
    var size_info = try self.generateArrayTypeSizeText(source_code, left_side);
    const right_side = this_node.right_side;
    const type_name = try self.generateIdentifierText(source_code, right_side);
    if (String.equalStr(type_name, "[]const u8")) {
        if (size_info[size_info.len - 2] == '[' and size_info[size_info.len - 1] == ']' and !source_code.is_array_init) {
            size_info = try String.replaceStr(self.memory, size_info, "]", "]const ");
        }
    }
    self.array_type_info = .{
        .name = type_name,
        .size_info = size_info,
    };
    return try String.concatStr(self.memory, &.{ size_info, type_name });
}
fn generatePointerTypeText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    var text = self.generateCodeByTokenIndex(this_node.main_token);
    const type_text = try self.generateExpressionText(source_code, this_node.right_side);
    text = try String.concatStr(self.memory, &.{ text, type_text });
    return text;
}
fn generateOptionalTypeText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    var text = self.generateCodeByTokenIndex(this_node.main_token);
    const type_text = try self.generateExpressionText(source_code, this_node.right_side);
    text = try String.concatStr(self.memory, &.{ text, type_text });
    return text;
}
fn generateErrorUnionTypeText(self: *GenZigCode, source_code: Code, node_index: NodeIndex) ![]const u8 {
    const this_node = try source_code.getNode(node_index);
    var text: []const u8 = "";
    const main_token = self.tokens[this_node.main_token];
    if (this_node.left_side != null_node_index) {
        const error_left_node = try source_code.getNode(this_node.left_side);
        const error_left_text = self.generateCodeByTokenIndex(error_left_node.main_token);
        text = try String.concatStr(self.memory, &.{ text, error_left_text });
    }
    const right_text = try self.generateExpressionText(source_code, this_node.right_side);
    text = try String.concatStr(self.memory, &.{ text, main_token.text, right_text });
    return text;
}
fn generateCodeByTokenIndex(self: *GenZigCode, token_index: TokenIndex) []const u8 {
    var text = self.tokens[token_index].text;
    if (String.equalStr(text, "str")) {
        text = "[]const u8";
    }
    return text;
}
const ArrayTypeInfo = struct {
    name: []const u8,
    size_info: []const u8,
};

const GenZigCode = @This();
