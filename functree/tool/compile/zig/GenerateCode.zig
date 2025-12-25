const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Util = @import("../Util.zig");
const Str = []const u8;

const Func = @import("../Func.zig");
const Statement = Func.Statement;
const TokenType = Func.TokenType;
const CodeNode = Func.CodeNode;
const NodeIndex = Func.NodeIndex;
const TokenIndex = Func.TokenIndex;
const TargetStatement = @import("../Translate.zig").TargetStatement;

const Parse = @import("../Parse.zig");
const root_node_index = Parse.root_node_index;
const null_node = Parse.null_node;

pub const GenerateCode = @This();

allocator: Allocator,
func: Func,
target_statement_list: *ArrayList(TargetStatement),
prefix_space: Str = "",
array_type_info: ?ArrayTypeInfo = null,
array_level: usize = 0,
if_else_flag_map: ?AutoHashMap(usize, bool) = null,

pub fn init(allocator: Allocator, func: Func, target_statement_list: *ArrayList(TargetStatement)) !GenerateCode {
    var self = GenerateCode{
        .allocator = allocator,
        .func = func,
        .target_statement_list = target_statement_list,
    };
    try self.generateTargetStatementList();
    return self;
}
pub fn deinit(self: *GenerateCode) void {
    // for (self.source_file_path_list.items) |item| {
    //     self.source_file_path_list.allocator.free(item);
    // }
    // self.source_file_path_list.deinit();
    self.* = undefined;
}
fn printNodeMap(statement: Statement) !void {
    var iterator = statement.node_map.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const node = entry.value_ptr.*;
        std.debug.print("\n{d} : {any}\n", .{ key, node.node_type });
        if (node.left_side != null_node) {
            const node_index_list = statement.arg_node_index_map.getPtr(node.left_side);
            if (node_index_list == null) {
                const token_index = statement.getNode(node.left_side).main_token;
                const token = statement.getToken(token_index);
                std.debug.print("left: {d}='{s}', token_type={any}, line_no={d}, column_no={d}\n", .{ node.left_side, token.text, token.token_type, token.line_no, token.column_no });
            } else {
                for (node_index_list.?.*.items) |v_node_index| {
                    const token_index = statement.getNode(v_node_index).main_token;
                    const token = statement.getToken(token_index);
                    std.debug.print("left_v: {d}='{s}', token_type={any}, line_no={d}, column_no={d}\n", .{ v_node_index, token.text, token.token_type, token.line_no, token.column_no });
                }
            }
        }
        const maintoken = statement.getToken(node.main_token);
        std.debug.print("main_token: text='{s}', token_type={any}, line_no={d}, column_no={d}\n", .{ maintoken.text, maintoken.token_type, maintoken.line_no, maintoken.column_no });
        if (node.right_side != null_node) {
            const token_index = statement.getNode(node.right_side).main_token;
            const token = statement.getToken(token_index);
            std.debug.print("right: {d}='{s}', token_type={any}, line_no={d}, column_no={d}\n", .{ node.right_side, token.text, token.token_type, token.line_no, token.column_no });
        }
    }
    for (statement.child_list.items) |child_statement| {
        try printNodeMap(child_statement);
    }
}

fn generateTargetStatementList(self: *GenerateCode) !void {
    var line_no: usize = 1;
    var i: usize = 0;
    while (i < self.func.statement_list.items.len) {
        const statement = self.func.statement_list.items[i];
        line_no = statement.line_no;

        // try printNodeMap(statement);

        if (self.if_else_flag_map != null) {
            self.if_else_flag_map.?.deinit();
            self.if_else_flag_map = null;
        }
        self.if_else_flag_map = AutoHashMap(usize, bool).init(self.allocator);
        if (i < self.func.statement_list.items.len - 1) {
            const next_statement = self.func.statement_list.items[i + 1];
            if ((statement.code_type == .if_block or statement.code_type == .else_block) and next_statement.code_type == .else_block) {
                try self.if_else_flag_map.?.put(0, true);
            } else {
                try self.if_else_flag_map.?.put(0, false);
            }
        } else {
            try self.if_else_flag_map.?.put(0, false);
        }
        var target_statement = TargetStatement.init(self.allocator, line_no);
        const code_line = try self.generateTargetStatementText(statement, 0);
        try target_statement.appendCodeLineList(code_line);
        try self.target_statement_list.append(self.allocator, target_statement);
        i += 1;
    }
    const last_period_pos = std.mem.lastIndexOf(u8, self.func.name, ".");
    const import_line = try Util.concat(self.allocator, &.{ "\nconst ", self.func.name[last_period_pos.? + 1 ..], "=@This();" });
    var target_statement = TargetStatement.init(self.allocator, line_no + 1);
    try target_statement.appendCodeLineList(import_line);
    try self.target_statement_list.append(self.allocator, target_statement);
}

fn generateTargetStatementText(self: *GenerateCode, statement: Statement, level: usize) anyerror!Str {
    const prefix_space = try self.getPrefixSpace(level);
    switch (statement.code_type) {
        .declare_param => {
            return try self.generateParamCode(statement, level);
        },
        .define_var => {
            return try self.generateVarCode(statement, level);
        },
        .assign => {
            return try self.generateAssignCode(statement, level);
        },
        .call_fn => {
            return try self.generateCallFnCode(statement, level);
        },
        ._break => {
            return try Util.concat(self.allocator, &.{ prefix_space, "break;\n" });
        },
        ._continue => {
            return try Util.concat(self.allocator, &.{ prefix_space, "continue;\n" });
        },
        ._return => {
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, "return" });
            const root_node = statement.getNode(root_node_index);
            if (root_node.right_side != null_node) {
                const result = try self.generateExpressionText(statement, root_node.right_side);
                code_line = try Util.concat(self.allocator, &.{ code_line, " ", result });
            }
            code_line = try Util.concat(self.allocator, &.{ code_line, ";\n" });
            return code_line;
        },
        ._asm => {
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, "asm (" });
            const root_node = statement.getNode(root_node_index);
            const result = try self.generateExpressionText(statement, root_node.right_side);
            code_line = try Util.concat(self.allocator, &.{ code_line, prefix_space, result });
            code_line = try Util.concat(self.allocator, &.{ code_line, prefix_space, ");\n" });
            return code_line;
        },
        .code => {
            const root_node = statement.getNode(root_node_index);
            const right_node = statement.getNode(root_node.right_side);
            var main_text = statement.getToken(right_node.main_token).text;
            main_text = try std.mem.replaceOwned(u8, statement.arena, main_text, "'''", "");
            const code_line = try Util.concat(self.allocator, &.{ prefix_space, main_text, "\n" });
            return code_line;
        },
        ._try => {
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, "try " });
            const root_node = statement.getNode(root_node_index);
            const text = try self.generateExpressionText(statement, root_node.right_side);
            code_line = try Util.concat(self.allocator, &.{ code_line, text, ";\n" });
            return code_line;
        },
        .import => {
            const root_node = statement.getNode(root_node_index);
            const import_text = generateCodeByTokenIndex(statement, root_node.main_token);
            var arg_text = try self.generateExpressionText(statement, root_node.right_side);
            const import_fn_name = try Util.concat(self.allocator, &.{ prefix_space, "@", import_text, "(\"" });
            const func_paths = arg_text[1 .. arg_text.len - 1];
            var func_path_it = mem.splitScalar(u8, func_paths, ','); //mem.splitAny(u8, func_paths, ",");
            var import_line: Str = "";
            while (func_path_it.next()) |func_path| {
                const last_sep_pos = std.mem.lastIndexOf(u8, func_path, "/");
                const last_period_pos = std.mem.lastIndexOf(u8, func_path, ".");
                const func_file_name = func_path[last_sep_pos.? + 1 .. last_period_pos.?];
                var path_text = try std.mem.replaceOwned(u8, statement.arena, func_path, "/", "_");
                path_text = try std.mem.replaceOwned(u8, statement.arena, path_text, ".func", ".zig");
                import_line = try Util.concat(statement.arena, &.{ import_line, "const ", func_file_name, " = ", import_fn_name, path_text, "\");\n" });
            }
            return import_line;
        },

        .define_fn => {
            var code_line = prefix_space;
            const root_node = statement.getNode(root_node_index);
            if (root_node.left_side != null_node) {
                const text = try self.generateIdentifierText(statement, root_node.left_side);
                code_line = try Util.concat(self.allocator, &.{ code_line, text, " fn " });
            } else {
                code_line = try Util.concat(self.allocator, &.{ code_line, "fn " });
            }
            //fn_proto
            const fn_proto_node = statement.getNode(root_node.right_side);
            const fn_name = generateCodeByTokenIndex(statement, fn_proto_node.main_token);
            code_line = try Util.concat(self.allocator, &.{ code_line, fn_name, "(" });
            const fn_param_node = statement.getNode(fn_proto_node.left_side);
            const param_node_start = fn_param_node.left_side;
            if (param_node_start != null_node) {
                const arg_node_index_list = statement.arg_node_index_map.get(param_node_start);
                for (arg_node_index_list.?.items) |param_node_index| {
                    const param_node_text = try self.generateIdentifierAndTypeText(statement, param_node_index);
                    if (param_node_index == param_node_start) {
                        code_line = try Util.concat(statement.arena, &.{ code_line, param_node_text });
                    } else {
                        code_line = try Util.concat(statement.arena, &.{ code_line, ", ", param_node_text });
                    }
                }
            }
            code_line = try Util.concat(self.allocator, &.{ code_line, ") " });
            const result_text = try self.generateExpressionText(statement, fn_proto_node.right_side);
            const fn_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ code_line, result_text, " {\n", fn_body_text });
            return code_line;
        },
        ._block => {
            var code_line = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ prefix_space, "{\n", code_line });
            return code_line;
        },
        .if_block => {
            const root_node = statement.getNode(root_node_index);
            const main_token = statement.getToken(root_node.main_token);
            const left_side = root_node.left_side;
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, main_token.text, " (" });
            if (left_side != null_node) {
                const condition_node_index = left_side;
                const right_side = root_node.right_side;
                const condition = try self.generateExpressionText(statement, condition_node_index);
                const right_node = statement.getNode(right_side);
                var if_body_text: Str = undefined;
                switch (right_node.node_type) {
                    ._continue => if_body_text = "continue",
                    ._break => if_body_text = "break",
                    ._return => {
                        if (right_side != null_node) {
                            if_body_text = try self.generateExpressionText(statement, right_side);
                        } else {
                            if_body_text = "return";
                        }
                    },
                    ._try => {
                        if_body_text = try self.generateExpressionText(statement, right_side);
                    },
                    .assign => {
                        if_body_text = try self.generateAssignText(statement, right_side);
                    },
                    else => {
                        if_body_text = try self.generateExpressionText(statement, right_side);
                    },
                }
                code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") ", if_body_text, ";\n" });
            } else {
                const condition_node_index = root_node.right_side;
                const condition = try self.generateExpressionText(statement, condition_node_index);
                code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
                const if_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
                code_line = try Util.concat(self.allocator, &.{ code_line, if_body_text });
            }
            return code_line;
        },
        .else_block => {
            const root_node = statement.getNode(root_node_index);
            const main_token = statement.getToken(root_node.main_token);
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, "} ", main_token.text, " " });
            // else if
            const if_node_index = root_node.right_side;
            if (if_node_index != null_node) {
                code_line = try Util.concat(self.allocator, &.{ code_line, "if (" });
                const if_node = statement.getNode(if_node_index);
                const condition_node_index = if_node.right_side;
                const condition = try self.generateExpressionText(statement, condition_node_index);
                code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
            } else { // else
                code_line = try Util.concat(self.allocator, &.{ code_line, "{\n" });
            }
            const else_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ code_line, else_body_text });
            return code_line;
        },
        .switch_block => {
            const root_node = statement.getNode(root_node_index);
            var code_line = try self.generateSwitchCodeLine(statement, root_node);
            const switch_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ code_line, switch_body_text });
            return code_line;
        },
        .switch_case_block => {
            const root_node = statement.getNode(root_node_index);
            var code_line: Str = prefix_space;
            const case_node_index = root_node.left_side;
            const case_node = statement.getNode(case_node_index);
            const case_arg_start = case_node.left_side;
            if (case_arg_start != null_node) {
                const arg_node_index_list = statement.arg_node_index_map.get(case_arg_start);
                for (arg_node_index_list.?.items) |arg_node_index| {
                    const arg_node_text = try self.generateExpressionText(statement, arg_node_index);
                    if (arg_node_index == case_arg_start) {
                        code_line = try Util.concat(statement.arena, &.{ code_line, arg_node_text });
                    } else {
                        code_line = try Util.concat(statement.arena, &.{ code_line, ", ", arg_node_text });
                    }
                }
            }
            code_line = try Util.concat(self.allocator, &.{ code_line, " => " });
            const right_side = root_node.right_side;
            if (right_side != null_node) {
                const right_node = statement.getNode(right_side);
                switch (right_node.node_type) {
                    .if_block => {
                        code_line = try Util.concat(self.allocator, &.{ code_line, "if (" });
                        const condition_node_index = right_node.right_side;
                        const condition = try self.generateExpressionText(statement, condition_node_index);
                        code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
                        const if_body_text = try self.generateChildStatementText2(statement, level + 1, prefix_space);
                        code_line = try Util.concat(self.allocator, &.{ code_line, if_body_text });
                    },
                    .while_block => {
                        code_line = try Util.concat(self.allocator, &.{ code_line, "while (" });
                        const condition_node_index = right_node.right_side;
                        const condition = try self.generateExpressionText(statement, condition_node_index);
                        code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
                        const while_body_text = try self.generateChildStatementText2(statement, level + 1, prefix_space);
                        code_line = try Util.concat(self.allocator, &.{ code_line, while_body_text });
                    },
                    .switch_block => {
                        code_line = try Util.concat(self.allocator, &.{ code_line, "switch (" });
                        const condition_node_index = right_node.right_side;
                        const condition = try self.generateExpressionText(statement, condition_node_index);
                        code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
                        const switch_body_text = try self.generateChildStatementText2(statement, level + 1, prefix_space);
                        code_line = try Util.concat(self.allocator, &.{ code_line, switch_body_text });
                    },
                    .empty_block => {
                        code_line = try Util.concat(self.allocator, &.{ code_line, "{},\n" });
                    },
                    else => {
                        const text = try self.generateExpressionText(statement, right_side);
                        code_line = try Util.concat(self.allocator, &.{ code_line, text });
                        code_line = try Util.concat(self.allocator, &.{ code_line, ",\n" });
                    },
                }
            } else {
                code_line = try Util.concat(self.allocator, &.{ code_line, "{\n" });
                const case_body_text = try self.generateChildStatementText2(statement, level + 1, prefix_space);
                code_line = try Util.concat(self.allocator, &.{ code_line, case_body_text });
            }
            return code_line;
        },
        .test_block => {
            const root_node = statement.getNode(root_node_index);
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, "test " });
            if (root_node.right_side != null_node) {
                const test_name = try self.generateExpressionText(statement, root_node.right_side);
                code_line = try Util.concat(self.allocator, &.{ code_line, test_name, " {\n" });
            } else {
                code_line = try Util.concat(self.allocator, &.{ code_line, "{\n" });
            }
            const test_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ code_line, test_body_text });
            return code_line;
        },
        ._defer, ._errdefer, ._comptime => {
            const root_node = statement.getNode(root_node_index);
            const main_token = statement.getToken(root_node.main_token);
            var code_line = try Util.concat(self.allocator, &.{ prefix_space, main_token.text, " " });
            if (root_node.right_side != null_node) {
                const test_name = try self.generateExpressionText(statement, root_node.right_side);
                code_line = try Util.concat(self.allocator, &.{ code_line, test_name, ";\n" });
            } else {
                code_line = try Util.concat(self.allocator, &.{ code_line, "{\n" });
                const defer_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
                code_line = try Util.concat(self.allocator, &.{ code_line, defer_body_text });
            }
            return code_line;
        },
        .for_block => {
            const root_node = statement.getNode(root_node_index);
            var code_line: Str = prefix_space;
            if (statement.is_inline) {
                code_line = try Util.concat(self.allocator, &.{ code_line, "inline " });
            }
            code_line = try Util.concat(self.allocator, &.{ code_line, "for (" });
            const item_node = statement.getNode(root_node.left_side);
            var item_text: Str = undefined;
            if (item_node.node_type == .fn_arg) {
                item_text = try self.generateFnArgText(statement, item_node.left_side);
            } else {
                item_text = try self.generateExpressionText(statement, root_node.left_side);
            }
            const items_node = statement.getNode(root_node.right_side);
            var items_text: Str = undefined;
            if (items_node.node_type == .fn_arg) {
                items_text = try self.generateFnArgText(statement, items_node.left_side);
            } else {
                items_text = try self.generateExpressionText(statement, root_node.right_side);
            }
            code_line = try Util.concat(self.allocator, &.{ code_line, items_text, ") |", item_text, "| {\n" });
            const for_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ code_line, for_body_text });
            return code_line;
        },
        .while_block => {
            const root_node = statement.getNode(root_node_index);
            var code_line: Str = prefix_space;
            if (statement.is_inline) {
                code_line = try Util.concat(self.allocator, &.{ code_line, "inline " });
            }
            if (root_node.left_side == null_node) {
                code_line = try Util.concat(self.allocator, &.{ code_line, "while (" });
                const condition_node_index = root_node.right_side;
                const condition = try self.generateExpressionText(statement, condition_node_index);
                code_line = try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
            } else {
                code_line = try Util.concat(self.allocator, &.{ code_line, "while (" });
                const item_text = try self.generateExpressionText(statement, root_node.left_side);
                const items_text = try self.generateExpressionText(statement, root_node.right_side);
                code_line = try Util.concat(self.allocator, &.{ code_line, items_text, ") |", item_text, "| {\n" });
            }
            const while_body_text = try self.generateChildStatementText(statement, level + 1, prefix_space);
            code_line = try Util.concat(self.allocator, &.{ code_line, while_body_text });
            return code_line;
        },
        else => {
            unreachable;
        },
    }
}
fn generateChildStatementText(self: *GenerateCode, statement: Statement, level: usize, prefix_space: Str) !Str {
    // std.debug.print("parent_ir_code c = {any}, {any}, {d}\n", .{ code.code_type, code.child_list.items.len, code.line_no });
    var code_line: Str = "";
    var i: usize = 0;
    while (i < statement.child_list.items.len) {
        const child_statement = statement.child_list.items[i];
        if (i < statement.child_list.items.len - 1) {
            const next_statement = statement.child_list.items[i + 1];
            if ((child_statement.code_type == .if_block or child_statement.code_type == .else_block) and next_statement.code_type == .else_block) {
                try self.if_else_flag_map.?.put(level, true);
            } else {
                try self.if_else_flag_map.?.put(level, false);
            }
        } else {
            try self.if_else_flag_map.?.put(level, false);
        }
        // std.debug.print("generateTargetStatementText child_statement_list=={any}\n", .{child_statement});
        const child_text = try self.generateTargetStatementText(child_statement, level);
        code_line = try Util.concat(self.allocator, &.{ code_line, child_text });
        i += 1;
    }
    if (self.if_else_flag_map.?.get(level - 1) != true) {
        code_line = try Util.concat(self.allocator, &.{ code_line, prefix_space, "}\n" });
    }
    return code_line;
}
fn generateChildStatementText2(self: *GenerateCode, statement: Statement, level: usize, prefix_space: Str) !Str {
    // std.debug.print("parent_ir_code c = {any}, {any}, {d}\n", .{ code.code_type, code.child_list.items.len, code.line_no });
    var code_line: Str = "";
    for (statement.child_list.items) |child_statement| {
        // std.debug.print("generateTargetStatementText child_statement_list=={any}\n", .{child_statement});
        const child_text = try self.generateTargetStatementText(child_statement, level);
        code_line = try Util.concat(self.allocator, &.{ code_line, child_text });
    }
    code_line = try Util.concat(self.allocator, &.{ code_line, prefix_space, "},\n" });
    return code_line;
}

fn getPrefixSpace(self: *GenerateCode, level: usize) !Str {
    var prefix_space: Str = "";
    var count: usize = 0;
    while (count < level) {
        prefix_space = try Util.concat(self.allocator, &.{ prefix_space, "  " });
        count += 1;
    }
    self.prefix_space = prefix_space;
    return prefix_space;
}
fn generateSwitchCodeLine(self: *GenerateCode, statement: Statement, switch_node: CodeNode) !Str {
    const code_line = try Util.concat(self.allocator, &.{ self.prefix_space, "switch (" });
    const condition = try self.generateExpressionText(statement, switch_node.right_side);
    return try Util.concat(self.allocator, &.{ code_line, condition, ") {\n" });
}
fn generateParamCode(self: *GenerateCode, statement: Statement, level: usize) !Str {
    var code_line: Str = try self.getPrefixSpace(level);
    const root_node = statement.getNode(root_node_index);
    var text: Str = "";
    if (root_node.node_type == .assign) {
        text = try self.generateAssignText(statement, root_node_index);
    } else {
        text = try self.generateIdentifierAndTypeText(statement, root_node_index);
    }
    code_line = try Util.concat(self.allocator, &.{ code_line, text, ",\n" });
    return code_line;

    // try printNodeMap(statement);
}
fn generateVarCode(self: *GenerateCode, statement: Statement, level: usize) !Str {
    //std.debug.print("generateVarCode node_list=={any}\n", .{statement.node_map});
    var code_line: Str = try self.getPrefixSpace(level);
    const root_node = statement.getNode(root_node_index);
    if (root_node.left_side != null_node) {
        const text = try self.generateIdentifierAndTypeText(statement, root_node.left_side);
        code_line = try Util.concat(self.allocator, &.{ code_line, text, " " });
    }
    //const or var
    const token_text = generateCodeByTokenIndex(statement, root_node.main_token);
    code_line = try Util.concat(self.allocator, &.{ code_line, token_text, " " });
    const right_side = root_node.right_side;
    const right_token_index = statement.getNode(right_side).main_token;
    const right_token = statement.getToken(right_token_index);
    if (right_token.token_type == .equal) {
        const text = try self.generateAssignText(statement, right_side);
        code_line = try Util.concat(self.allocator, &.{ code_line, text, ";\n" });
    } else {
        const text = try self.generateExpressionText(statement, right_side);
        code_line = try Util.concat(self.allocator, &.{ code_line, text, ";\n" });
    }
    return code_line;

    // try printNodeMap(statement);
}
fn generateAssignCode(self: *GenerateCode, statement: Statement, level: usize) !Str {
    var code_line: Str = try self.getPrefixSpace(level);
    const text = try self.generateAssignText(statement, root_node_index);
    code_line = try Util.concat(self.allocator, &.{ code_line, text, ";\n" });
    return code_line;
    // if (statement.line_no == 10)
    //     try printNodeMap(statement);
}
fn generateCallFnCode(self: *GenerateCode, statement: Statement, level: usize) !Str {
    var code_line: Str = try self.getPrefixSpace(level);
    const text = try self.generateExpressionText(statement, root_node_index);
    code_line = try Util.concat(self.allocator, &.{ code_line, text, ";\n" });
    return code_line;

    // try printNodeMap(statement);
}

fn generateAssignText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const equal_node = statement.getNode(node_index);
    const left_side = equal_node.left_side;
    var text = try self.generateIdentifierAndTypeText(statement, left_side);
    const main_token = statement.getToken(equal_node.main_token);
    text = try Util.concat(statement.arena, &.{ text, " ", main_token.text, " " });

    const right_text = try self.generateExpressionText(statement, equal_node.right_side);
    text = try Util.concat(statement.arena, &.{ text, right_text });
    return text;
}
fn generateFnArgText(self: *GenerateCode, statement: Statement, arg_node_start: NodeIndex) !Str {
    var text: Str = "";
    self.array_type_info = null;
    const arg_node_index_list = statement.arg_node_index_map.get(arg_node_start);
    for (arg_node_index_list.?.items) |arg_node_index| {
        const arg_node_text = try self.generateExpressionText(statement, arg_node_index);
        if (arg_node_index == arg_node_start) {
            text = try Util.concat(statement.arena, &.{arg_node_text});
        } else {
            text = try Util.concat(statement.arena, &.{ text, ", ", arg_node_text });
        }
    }
    return text;
}
fn generateExpressionText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) anyerror!Str {
    const this_node = statement.getNode(node_index);
    const left_side = this_node.left_side;
    const right_side = this_node.right_side;
    var text: Str = "";
    switch (this_node.node_type) {
        .if_else_line => {
            text = try Util.concat(statement.arena, &.{ text, "if (" });
            const left_node = statement.getNode(left_side);
            const condition_text = try self.generateExpressionText(statement, left_node.left_side);
            const if_value_text = try self.generateExpressionText(statement, left_node.right_side);
            text = try Util.concat(statement.arena, &.{ text, condition_text, ") ", if_value_text });

            const else_value_text = try self.generateExpressionText(statement, right_side);
            text = try Util.concat(statement.arena, &.{ text, " else ", else_value_text });
        },
        .func_init => {
            text = try self.generateFuncInitText(statement, node_index);
        },
        .container_decl => {
            text = try self.generateContainerDeclareText(statement, node_index);
        },
        .grouped_expression => {
            text = generateCodeByTokenIndex(statement, this_node.main_token);
            const left_text = try self.generateExpressionText(statement, left_side);
            text = try Util.concat(statement.arena, &.{ text, left_text });
            const token_index = statement.getNode(right_side).main_token;
            const right_text = generateCodeByTokenIndex(statement, token_index);
            text = try Util.concat(statement.arena, &.{ text, right_text });
        },
        .call_fn => {
            text = try self.generateExpressionText(statement, left_side);
            const l_paren_text = generateCodeByTokenIndex(statement, this_node.main_token);
            text = try Util.concat(statement.arena, &.{ text, l_paren_text });
            const right_node = statement.getNode(right_side);
            if (right_node.left_side != null_node) {
                const arg_text = try self.generateFnArgText(statement, right_node.left_side);
                text = try Util.concat(statement.arena, &.{ text, arg_text });
            }
            const r_paren_text = generateCodeByTokenIndex(statement, right_node.main_token);
            text = try Util.concat(statement.arena, &.{ text, r_paren_text });
        },
        .import_func => {
            const import_text = generateCodeByTokenIndex(statement, this_node.main_token);
            text = try Util.concat(statement.arena, &.{ "@", import_text, "(" });
            var arg_text = try self.generateExpressionText(statement, right_side);
            arg_text = try std.mem.replaceOwned(u8, statement.arena, arg_text, "/", "_");
            arg_text = try std.mem.replaceOwned(u8, statement.arena, arg_text, ".func", ".zig");
            text = try Util.concat(statement.arena, &.{ text, arg_text, ")" });
        },
        ._catch => {
            text = try self.generateExpressionText(statement, left_side);
            const catch_text = generateCodeByTokenIndex(statement, this_node.main_token);
            text = try Util.concat(statement.arena, &.{ text, " ", catch_text });
            var right_text: Str = "";
            // std.debug.print("_catch = {any}\n", .{right_side});
            if (right_side == null_node) {
                right_text = " {\n";
                for (statement.child_list.items) |child_statement| {
                    const child_text = try self.generateTargetStatementText(child_statement, 1);
                    right_text = try Util.concat(self.allocator, &.{ right_text, child_text });
                }
                right_text = try Util.concat(self.allocator, &.{ right_text, "}" });
            } else {
                const right_node = statement.getNode(right_side);
                if (right_node.node_type == .catch_body) {
                    const catch_arg = try self.generateIdentifierText(statement, right_node.left_side);
                    right_text = try Util.concat(statement.arena, &.{ " |", catch_arg, "| " });
                    if (right_node.right_side == null_node) {
                        right_text = try Util.concat(self.allocator, &.{ right_text, "{\n" });
                        for (statement.child_list.items) |child_statement| {
                            const child_text = try self.generateTargetStatementText(child_statement, 1);
                            right_text = try Util.concat(self.allocator, &.{ right_text, child_text });
                        }
                        right_text = try Util.concat(self.allocator, &.{ right_text, "}" });
                    } else {
                        const body_right_node = statement.getNode(right_node.right_side);
                        switch (body_right_node.node_type) {
                            ._return => {
                                right_text = try Util.concat(statement.arena, &.{ right_text, "return " });
                                const condition = try self.generateExpressionText(statement, body_right_node.right_side);
                                right_text = try Util.concat(statement.arena, &.{ right_text, condition });
                            },
                            .call_fn => {
                                const right_text2 = try self.generateExpressionText(statement, right_node.right_side);
                                right_text = try Util.concat(statement.arena, &.{ right_text, right_text2 });
                            },
                            else => {
                                unreachable;
                            },
                        }
                    }
                } else if (right_node.right_side == null_node) {
                    right_text = generateCodeByTokenIndex(statement, right_node.main_token);
                    right_text = try Util.concat(statement.arena, &.{ " ", right_text });
                } else {
                    const right_text2 = try self.generateExpressionText(statement, right_side);
                    right_text = try Util.concat(statement.arena, &.{ right_text, " ", right_text2 });
                }
            }
            text = try Util.concat(statement.arena, &.{ text, right_text });
        },
        .array_init => {
            self.array_level = 0;
            text = try self.generateArrayInitText(statement, node_index, 0);
        },
        .array_type => {
            self.array_level = 0;
            text = try self.generateArrayTypeText(statement, node_index);
        },
        .error_union => {
            return self.generateErrorUnionTypeText(statement, node_index);
        },
        .pointer_type => {
            return self.generatePointerTypeText(statement, node_index);
        },
        .optional_type => {
            return self.generateOptionalTypeText(statement, node_index);
        },
        .array_access => {
            const left_text = try self.generateExpressionText(statement, left_side);
            text = try Util.concat(statement.arena, &.{ text, left_text, "[" });
            const right_text = try self.generateArrayAccessRightText(statement, right_side);
            text = try Util.concat(statement.arena, &.{ text, right_text });
        },
        .deref, .unwrap_optional => { //.* 或 //.?
            if (left_side != null_node) {
                text = try self.generateExpressionText(statement, left_side);
            }
            // main_token is period_asterisk or period_question
            const main_token_text = generateCodeByTokenIndex(statement, this_node.main_token);
            text = try Util.concat(statement.arena, &.{ text, main_token_text });
        },
        .field_access => { //.red
            text = try self.generateFieldAccessCode(statement, node_index);
        },
        .func_init_dot => { // ".{"
            const func_init_dot_text = try self.generateFuncInitDotText(statement, node_index);
            text = try Util.concat(statement.arena, &.{ text, func_init_dot_text });
        },
        .empty_block => {
            text = "{}";
        },
        .align_type, .callconv_type => {
            const align_text = generateCodeByTokenIndex(statement, this_node.main_token);
            const arg_text = try self.generateExpressionText(statement, right_side);
            text = try Util.concat(statement.arena, &.{ text, align_text, "(", arg_text, ")" });
        },
        .fn_type => {
            const fn_text = generateCodeByTokenIndex(statement, this_node.main_token);
            text = try Util.concat(self.allocator, &.{ text, " ", fn_text, " (" });
            //fn_param
            const fn_param_node = statement.getNode(left_side);
            const param_node_start = fn_param_node.left_side;
            if (param_node_start != null_node) {
                const arg_node_index_list = statement.arg_node_index_map.get(param_node_start);
                for (arg_node_index_list.?.items) |param_node_index| {
                    const param_node_text = try self.generateIdentifierAndTypeText(statement, param_node_index);
                    if (param_node_index == param_node_start) {
                        text = try Util.concat(statement.arena, &.{ text, param_node_text });
                    } else {
                        text = try Util.concat(statement.arena, &.{ text, ", ", param_node_text });
                    }
                }
            }
            text = try Util.concat(self.allocator, &.{ text, ") " });
            const result_text = try self.generateExpressionText(statement, right_side);
            text = try Util.concat(self.allocator, &.{ text, result_text });
        },
        .type_expr => {
            const left_text = try self.generateExpressionText(statement, left_side);
            text = try Util.concat(statement.arena, &.{ text, " ", left_text });
            const right_text = try self.generateExpressionText(statement, right_side);
            text = try Util.concat(statement.arena, &.{ text, " ", right_text });
        },
        else => {
            if (left_side != null_node) {
                const left_text = try self.generateExpressionText(statement, left_side);
                text = left_text;
            }
            var main_token_text = generateCodeByTokenIndex(statement, this_node.main_token);
            //multiline_string_literal
            if (this_node.node_type == .multiline_string_literal) {
                main_token_text = try std.mem.replaceOwned(u8, statement.arena, main_token_text, "'''", "");
                const replaceStr = try Util.concat(statement.arena, &.{ "\n", self.prefix_space, "\\\\" });
                main_token_text = try std.mem.replaceOwned(u8, statement.arena, main_token_text, "\n", replaceStr);
                main_token_text = try Util.concat(statement.arena, &.{ main_token_text, "\n" });
            }
            if (Util.isEql(text, "")) {
                text = main_token_text;
            } else {
                if (this_node.node_type == .switch_range) {
                    text = try Util.concat(statement.arena, &.{ text, main_token_text });
                } else {
                    text = try Util.concat(statement.arena, &.{ text, " ", main_token_text });
                }
            }
            if (right_side != null_node) {
                const right_text = try self.generateExpressionText(statement, right_side);
                switch (this_node.node_type) {
                    .negation, .bool_not, .bit_not, .address_of, .switch_range => {
                        text = try Util.concat(statement.arena, &.{ text, right_text });
                    },
                    else => {
                        text = try Util.concat(statement.arena, &.{ text, " ", right_text });
                    },
                }
            }
        },
    }
    return text;
}
fn generateArrayAccessRightText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    var text: Str = "";
    const this_node = statement.getNode(node_index); // main_token is ']'
    const left_side = this_node.left_side;
    const left_node = statement.getNode(left_side);
    if (left_node.node_type == .slice) { //[1..2], main_token is '..'
        const left_text = try self.generateExpressionText(statement, left_node.left_side);
        text = try Util.concat(statement.arena, &.{ text, left_text, ".." });
        if (left_node.right_side != null_node) {
            const right_text = try self.generateExpressionText(statement, left_node.right_side);
            text = try Util.concat(statement.arena, &.{ text, right_text });
        }
    } else {
        const left_text = try self.generateExpressionText(statement, left_side);
        text = try Util.concat(statement.arena, &.{ text, left_text });
    }
    text = try Util.concat(statement.arena, &.{ text, "]" });
    if (this_node.right_side != null_node) {
        const right_node = statement.getNode(this_node.right_side);
        const main_token2 = statement.getToken(right_node.main_token);
        var right_text2: Str = "";
        if (main_token2.token_type == .l_bracket) {
            text = try Util.concat(statement.arena, &.{ text, "[" });
            right_text2 = try self.generateArrayAccessRightText(statement, right_node.right_side);
        } else {
            right_text2 = try self.generateExpressionText(statement, this_node.right_side);
        }
        text = try Util.concat(statement.arena, &.{ text, right_text2 });
    }
    return text;
}
fn generateArrayInitText(self: *GenerateCode, statement: Statement, node_index: NodeIndex, level: usize) !Str {
    var text: Str = "";
    const this_node = statement.getNode(node_index);
    const left_side = this_node.left_side;
    const right_side = this_node.right_side;
    const right_node = statement.getNode(right_side);
    if (this_node.node_type == .array_init) {
        const size_info = try self.getArrayInitSizeInfoText(statement, level);
        if (self.array_type_info == null) { //array not defined type
            text = try Util.concat(statement.arena, &.{".{"});
        } else {
            text = try Util.concat(statement.arena, &.{ size_info, self.array_type_info.?.name, "{" });
        }
        if (right_node.node_type == .array_init) {
            const array_init_text = try self.generateArrayInitText(statement, right_side, level + 1);
            text = try Util.concat(statement.arena, &.{ text, array_init_text });
        } else if (right_node.node_type == .array_init_comma) {
            const left_text = try self.generateArrayInitText(statement, right_node.left_side, level + 1);
            const right_text = try self.generateArrayInitText(statement, right_node.right_side, level + 1);
            text = try Util.concat(statement.arena, &.{ text, left_text, ", ", right_text });
        } else if (right_node.node_type == .array_init_value) {
            if (right_node.left_side == null_node) {
                const array_init_text = try self.generateArrayInitText(statement, right_node.right_side, level + 1);
                text = try Util.concat(statement.arena, &.{ text, array_init_text, "}" });
            } else {
                const array_value_start = right_node.left_side;
                if (array_value_start != null_node) {
                    const arg_node_index_list = statement.arg_node_index_map.get(array_value_start);
                    for (arg_node_index_list.?.items) |array_value_node_index| {
                        const array_value_node_text = try self.generateExpressionText(statement, array_value_node_index);
                        if (array_value_node_index == array_value_start) {
                            text = try Util.concat(statement.arena, &.{ text, array_value_node_text });
                        } else {
                            text = try Util.concat(statement.arena, &.{ text, ", ", array_value_node_text });
                        }
                    }
                }
                text = try Util.concat(statement.arena, &.{ text, "}" });
            }
        } else {
            std.debug.print("<<<<<<<<<<<<<<<<<<<<<=={any}\n", .{right_node});
        }
    } else if (this_node.node_type == .array_init_comma) {
        const left_text = try self.generateArrayInitText(statement, left_side, level);
        const right_text = try self.generateArrayInitText(statement, right_side, level);
        text = try Util.concat(statement.arena, &.{ left_text, ", ", right_text });
    } else if (this_node.node_type == .array_init_value) {
        self.array_level += 1;
        const right_text = try self.generateArrayInitText(statement, right_side, level + 1);
        text = try Util.concat(statement.arena, &.{ right_text, "}" });
    } else {
        std.debug.print(",,,,,,,,,,,,,,,,=={any}\n", .{this_node});
    }
    return text;
}
fn getArrayInitSizeInfoText(self: *GenerateCode, statement: Statement, level: usize) !Str {
    var text: Str = "";
    if (self.array_type_info == null) return text;
    var r_bracket_count: usize = 0;
    const size_info = self.array_type_info.?.size_info;
    const array_len = size_info.len;
    const current_level = level - self.array_level;
    for (size_info, 0..) |char, index| {
        if (r_bracket_count >= current_level) {
            const string: Str = &.{char};
            if (index < array_len - 1 and size_info[index + 1] == ']' and char == '[') {
                if (!Util.isEql(size_info[index..], "[]const ")) { //not "[]const"
                    text = try Util.concat(statement.arena, &.{ text, string, "_" });
                } else {
                    text = try Util.concat(statement.arena, &.{ text, string });
                }
            } else {
                text = try Util.concat(statement.arena, &.{ text, string });
            }
        }
        if (char == ']') {
            r_bracket_count += 1;
        }
    }
    return text;
}
fn generateArrayTypeSizeText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    var text: Str = "[";
    const this_node = statement.getNode(node_index);
    if (this_node.left_side != null_node) {
        const left_node = statement.getNode(this_node.left_side);
        const array_size_token_text = generateCodeByTokenIndex(statement, left_node.main_token);
        text = try Util.concat(statement.arena, &.{ text, array_size_token_text, "]" });
    } else {
        text = try Util.concat(statement.arena, &.{ text, "]" });
    }
    if (this_node.right_side != null_node) {
        text = try Util.concat(statement.arena, &.{ text, try self.generateArrayTypeSizeText(statement, this_node.right_side) });
    }
    return text;
}
fn generateFuncInitText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    var text: Str = "";
    const this_node = statement.getNode(node_index);
    const func_name = generateCodeByTokenIndex(statement, this_node.main_token);
    text = try Util.concat(statement.arena, &.{ text, func_name, " {" });
    const right_side = this_node.right_side;
    const func_arg_node = statement.getNode(right_side);
    const arg_node_start = func_arg_node.right_side;
    if (arg_node_start != null_node) {
        const prefix_space = try Util.concat(self.allocator, &.{ self.prefix_space, "  " });
        text = try Util.concat(statement.arena, &.{ text, "\n" });
        const field_node_index_list = statement.arg_node_index_map.get(arg_node_start);
        for (field_node_index_list.?.items) |arg_node_index| {
            const arg_node_text = try self.generateFuncInitArgText(statement, arg_node_index);
            text = try Util.concat(statement.arena, &.{ text, prefix_space, arg_node_text, ",\n" });
        }
        text = try Util.concat(statement.arena, &.{ text, self.prefix_space, "}" });
    } else {
        text = try Util.concat(statement.arena, &.{ text, "}" });
    }
    return text;
}
fn generateFuncInitDotText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    var text: Str = "";
    const this_node = statement.getNode(node_index);
    text = try Util.concat(statement.arena, &.{ text, ".{" });
    const arg_node_start = this_node.right_side;
    if (arg_node_start != null_node) {
        const prefix_space = try Util.concat(self.allocator, &.{ self.prefix_space, "  " });
        text = try Util.concat(statement.arena, &.{ text, "\n" });
        const field_node_index_list = statement.arg_node_index_map.get(arg_node_start);
        for (field_node_index_list.?.items) |arg_node_index| {
            const arg_node_text = try self.generateFuncInitArgText(statement, arg_node_index);
            text = try Util.concat(statement.arena, &.{ text, prefix_space, arg_node_text, ",\n" });
        }
        text = try Util.concat(statement.arena, &.{ text, self.prefix_space, "}" });
    } else {
        text = try Util.concat(statement.arena, &.{ text, "}" });
    }
    return text;
}
fn generateFuncInitArgText(self: *GenerateCode, statement: Statement, arg_node_index: NodeIndex) !Str {
    const arg_node = statement.getNode(arg_node_index);
    if (statement.getToken(arg_node.main_token).token_type == .equal) {
        const left_side = arg_node.left_side;
        var text = try self.generateIdentifierAndTypeText(statement, left_side);
        text = try Util.concat(statement.arena, &.{ ".", text, " = " });

        const right_side = arg_node.right_side;
        const right_text = try self.generateExpressionText(statement, right_side);
        return try Util.concat(statement.arena, &.{ text, right_text });
    } else {
        return self.generateExpressionText(statement, arg_node_index);
    }
}
fn generateContainerDeclareText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    var text: Str = "";
    const this_node = statement.getNode(node_index);
    var container_name = generateCodeByTokenIndex(statement, this_node.main_token);
    if (Util.isEql(container_name, "func")) {
        container_name = "struct";
    }
    text = try Util.concat(statement.arena, &.{ text, container_name });
    const left_side = this_node.left_side;
    if (left_side != null_node) {
        text = try Util.concat(statement.arena, &.{ text, "(" });
        const tag_node_text = try self.generateIdentifierAndTypeText(statement, left_side);
        text = try Util.concat(statement.arena, &.{ text, tag_node_text, ")" });
    }
    const right_side = this_node.right_side;
    const container_field_node = statement.getNode(right_side);
    const field_node_start = container_field_node.right_side;
    text = try Util.concat(statement.arena, &.{ text, " {" });
    if (!statement.is_fn) {
        text = try Util.concat(statement.arena, &.{ text, "\n" });
    }
    if (field_node_start != null_node) {
        const prefix_space = try Util.concat(self.allocator, &.{ self.prefix_space, "  " });
        const field_node_index_list = statement.arg_node_index_map.get(field_node_start);
        var count: usize = 0;
        for (field_node_index_list.?.items, 0..) |field_node_index, index| {
            const field_node = statement.getNode(field_node_index);
            var field_node_text: Str = undefined;
            if (field_node.node_type == .func_init_arg) {
                field_node_text = try self.generateAssignText(statement, field_node_index);
            } else {
                field_node_text = try self.generateIdentifierAndTypeText(statement, field_node_index);
            }
            text = try Util.concat(statement.arena, &.{ text, prefix_space, field_node_text });
            if (!statement.is_fn) {
                text = try Util.concat(statement.arena, &.{ text, ",\n" });
            } else {
                if (index < field_node_index_list.?.items.len - 1) {
                    text = try Util.concat(statement.arena, &.{ text, "," });
                }
            }
            count += 1;
        }
        text = try Util.concat(statement.arena, &.{ text, self.prefix_space, "}" });
    } else {
        text = try Util.concat(statement.arena, &.{ text, "}" });
    }
    return text;
}
fn generateIdentifierAndTypeText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    switch (this_node.node_type) {
        .identifier => {
            return self.generateIdentifierText(statement, node_index);
        },
        .field_access => {
            return self.generateFieldAccessCode(statement, node_index);
        },
        .array_type => {
            return self.generateArrayTypeText(statement, node_index);
        },
        .array_access => {
            return self.generateExpressionText(statement, node_index);
        },
        .deref => {
            var text: Str = "";
            if (this_node.left_side != null_node) {
                text = try self.generateExpressionText(statement, this_node.left_side);
            }
            // main_token is period_asterisk
            const main_token_text = generateCodeByTokenIndex(statement, this_node.main_token);
            text = try Util.concat(statement.arena, &.{ text, main_token_text });
            return text;
        },
        .var_decl => {
            var text = generateCodeByTokenIndex(statement, this_node.main_token);
            if (this_node.right_side != null_node) {
                const node_text = try self.generateExpressionText(statement, this_node.right_side);
                if (!statement.is_array_init) { //非数组初始化定义
                    text = try Util.concat(statement.arena, &.{ text, ": ", node_text });
                }
            }
            return text;
        },
        ._comptime => {
            var text = generateCodeByTokenIndex(statement, this_node.main_token);
            if (this_node.right_side != null_node) {
                const node_text = try self.generateIdentifierAndTypeText(statement, this_node.right_side);
                text = try Util.concat(statement.arena, &.{ text, " ", node_text });
            }
            return text;
        },
        .error_union => {
            return self.generateErrorUnionTypeText(statement, node_index);
        },
        .pointer_type => {
            return self.generatePointerTypeText(statement, node_index);
        },
        .optional_type => {
            return self.generateOptionalTypeText(statement, node_index);
        },
        else => {
            std.debug.print("----------------generateIdentifierAndTypeText--{any}\n", .{this_node.node_type});
            unreachable;
        },
    }
}
fn generateIdentifierText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    var text: Str = generateCodeByTokenIndex(statement, this_node.main_token);
    if (this_node.left_side != null_node) {
        const left_text = try self.generateIdentifierAndTypeText(statement, this_node.left_side);
        text = try Util.concat(statement.arena, &.{ left_text, " ", text });
    }
    if (this_node.right_side != null_node) {
        const right_text = try self.generateIdentifierAndTypeText(statement, this_node.right_side);
        text = try Util.concat(statement.arena, &.{ text, " ", right_text });
    }
    return text;
}
fn generateFieldAccessCode(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    var text: Str = "";
    const left_side = this_node.left_side;
    if (left_side != null_node) {
        const left_text = try self.generateExpressionText(statement, left_side);
        text = try Util.concat(statement.arena, &.{ text, left_text });
    }
    // main_token is dot
    const main_token_text = generateCodeByTokenIndex(statement, this_node.main_token);
    text = try Util.concat(statement.arena, &.{ text, main_token_text });
    const right_side = this_node.right_side;
    if (right_side != null_node) {
        const right_token_text = try self.generateExpressionText(statement, right_side);
        text = try Util.concat(statement.arena, &.{ text, right_token_text });
    }
    return text;
}
fn generateArrayTypeText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    const left_side = this_node.left_side;
    var size_info = try self.generateArrayTypeSizeText(statement, left_side);

    const right_side = this_node.right_side;
    const type_name = try self.generateIdentifierText(statement, right_side);
    if (Util.isEql(type_name, "[]const u8")) {
        if (size_info[size_info.len - 2] == '[' and size_info[size_info.len - 1] == ']' and !statement.is_array_init) {
            size_info = try std.mem.replaceOwned(u8, statement.arena, size_info, "]", "]const ");
        }
    }
    self.array_type_info = .{ .name = type_name, .size_info = size_info };

    return try Util.concat(statement.arena, &.{ size_info, type_name });
}
fn generatePointerTypeText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    //main_token is '*'
    var text = generateCodeByTokenIndex(statement, this_node.main_token);
    const type_text = try self.generateExpressionText(statement, this_node.right_side);
    text = try Util.concat(statement.arena, &.{ text, type_text });
    return text;
}
fn generateOptionalTypeText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    //main_token is '?'
    var text = generateCodeByTokenIndex(statement, this_node.main_token);
    const type_text = try self.generateExpressionText(statement, this_node.right_side);
    text = try Util.concat(statement.arena, &.{ text, type_text });
    return text;
}
fn generateErrorUnionTypeText(self: *GenerateCode, statement: Statement, node_index: NodeIndex) !Str {
    const this_node = statement.getNode(node_index);
    var text: Str = "";
    const main_token = statement.getToken(this_node.main_token);
    if (this_node.left_side != null_node) {
        const error_left_node = statement.getNode(this_node.left_side);
        const error_left_text = generateCodeByTokenIndex(statement, error_left_node.main_token);
        text = try Util.concat(statement.arena, &.{ text, error_left_text });
    }
    const right_text = try self.generateExpressionText(statement, this_node.right_side);
    text = try Util.concat(statement.arena, &.{ text, main_token.text, right_text });
    return text;
}

fn generateCodeByTokenIndex(statement: Statement, token_index: TokenIndex) Str {
    var text = statement.getToken(token_index).text;
    if (Util.isEql(text, "str")) {
        text = "[]const u8";
    }
    return text;
}
const ArrayTypeInfo = struct {
    name: Str,
    size_info: Str,
};
