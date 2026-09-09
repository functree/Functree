const Config = @import("../../Config.zig");

const System = @import("../../System.zig");
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

const Func = @import("../Func.zig");

const Code = Func.Code;
const CodeType = Code.CodeType;
const CodeError = Code.CodeError;

const Token = Func.Token;
const TokenType = Token.TokenType;
const TokenIndex = Token.TokenIndex;

const Node = Func.Node;
const NodeType = Node.NodeType;
const NodeIndex = Node.NodeIndex;
const null_node_index = Node.null_node_index;

const DependFunc = Func.DependFunc;
const DependType = DependFunc.DependType;

memory: *Memory,
this_func: *Func,
tokens: []Token,
index: TokenIndex,
error_func_code: ?Code = null,

pub fn a(memory: *Memory, this_func: *Func) CodeParse {
    const self = CodeParse{
        .memory = memory,
        .this_func = this_func,
        .tokens = this_func.token_list.values(),
        .index = 0,
    };
    return self;
}

pub fn d(self: *CodeParse) void {
    self.* = undefined;
}

pub fn getErrorText(err: CodeError) []const u8 {
    switch (err) {
        CodeError.invalid_catch_code => return "invalid_catch_code",
        CodeError.expected_r_brace => return "expected_r_brace",
        CodeError.expected_else_expression => return "expected_else_expression",
        CodeError.expected_identifier => return "expected_identifier",
        CodeError.expected_identifier_value => return "expected_identifier_value",
        CodeError.expected_fn_result => return "expected_fn_result",
        CodeError.expected_capitalization_for_container_name => return "expected_capitalization_for_container_name",
        CodeError.expected_no_capitalization_for_function_name => return "expected_no_capitalization_for_function_name",
        CodeError.skip_one_invalid_token_type => return "skip_one_invalid_token_type",
        CodeError.catch_block_invalid_token_type => return "catch_block_invalid_token_type",
        CodeError.define_fn_invalid_token_type => return "define_fn_invalid_token_type",
        CodeError.invalid_symbol_type => return "invalid_symbol_type",
        CodeError.define_var_invalid_operator => return "define_var_invalid_operator",
        CodeError.expected_data_type => return "expected_data_type",
        CodeError.expected_array_type => return "expected_array_type",
        CodeError.expected_semicolon => return "expected_semicolon",
        CodeError.unknow_code_type => return "unknow_code_type",
        CodeError.invalid_code_type => return "invalid_code_type",
        CodeError.code_node_is_null => return "code_node_is_null",
        CodeError.invalid_token_type => return "invalid_token_type",
        CodeError.redeclaration_of_variable => return "redeclaration_of_variable",
        CodeError.out_of_memory => return "out_of_memory",
    }
}

pub fn next(self: *CodeParse, parent_code: ?*Code) CodeError!Code {
    var func_code: Code = undefined;
    if (parent_code == null) {
        func_code = Code.a(self.memory, self.index, null);
    } else {
        func_code = Code.a(self.memory, self.index, parent_code);
    }
    while (self.index < self.tokens.len) {
        const token = self.tokens[self.index];
        switch (token.token_type) {
            .keyword_pub => {
                func_code.is_pub = true;
            },
            .keyword_const, .keyword_var => {
                func_code.has_const_var = true;
                if (func_code.code_type == .unkown) func_code.code_type = .define_var;
            },
            .colon => {
                if (func_code.code_type == .unkown and !func_code.has_const_var) {
                    func_code.code_type = .declare_param;
                }
            },
            .keyword_break => {
                if (func_code.code_type == .unkown) func_code.code_type = ._break;
            },
            .keyword_continue => {
                if (func_code.code_type == .unkown) func_code.code_type = ._continue;
            },
            .keyword_unreachable => {
                if (func_code.code_type == .unkown) func_code.code_type = ._unreachable;
            },
            .keyword_return => {
                if (func_code.code_type == .unkown) func_code.code_type = ._return;
            },
            .keyword_try => {
                if (func_code.code_type == .unkown) func_code.code_type = ._try;
            },
            .keyword_include => {
                func_code.code_type = ._include;
            },
            .keyword_defer => {
                func_code.code_type = ._defer;
            },
            .keyword_errdefer => {
                func_code.code_type = ._errdefer;
            },
            .keyword_asm => {
                func_code.code_type = ._asm;
            },
            .keyword_code => {
                func_code.code_type = ._code;
            },
            .l_paren => {
                if (func_code.code_type == .unkown) {
                    func_code.code_type = .call_fn;
                } else if (func_code.code_type == .declare_param) {
                    func_code.has_call_fn = true;
                }
            },
            .r_paren => {
                if (func_code.code_type == .declare_param and func_code.has_call_fn) {
                    func_code.has_call_fn = false;
                }
            },
            .keyword_enum, .keyword_union, .keyword_func, .keyword_struct => {
                func_code.is_container = true;
            },
            .keyword_error => {
                if (self.tokens[self.index + 1].token_type == .l_brace) func_code.is_container = true;
            },
            .equal, .plus_equal, .minus_equal, .asterisk_equal, .slash_equal, .percent_equal, .ampersand_equal, .caret_equal, .pipe_equal, .angle_bracket_angle_bracket_left_equal, .angle_bracket_angle_bracket_right_equal => {
                if (func_code.code_type == .unkown) func_code.code_type = .assign;
            },
            .semicolon => {
                try self.parseCode(&func_code);
                break;
            },
            .comma => {
                if (func_code.code_type == .declare_param and !func_code.has_call_fn) {
                    try self.parseCode(&func_code);
                    break;
                }
            },
            .equal_angle_bracket_right => {
                func_code.code_type = .switch_case_block;
                try self.parseCode(&func_code);
                break;
            },
            .keyword_fn => {
                if (func_code.code_type == .unkown) {
                    func_code.code_type = .define_fn;
                } else if (func_code.code_type == .define_var) {
                    func_code.is_fn = true;
                }
            },
            .keyword_if => {
                if (func_code.code_type == .unkown) func_code.code_type = .if_block;
            },
            .keyword_else => {
                if (func_code.code_type == .unkown) {
                    if (self.tokens[self.index + 1].token_type == .keyword_if) {
                        func_code.code_type = .else_if_block;
                        self.index += 1;
                    } else {
                        func_code.code_type = .else_block;
                    }
                }
            },
            .keyword_for => {
                func_code.code_type = .for_block;
            },
            .keyword_while => {
                func_code.code_type = .while_block;
            },
            .keyword_switch => {
                func_code.code_type = .switch_block;
            },
            .keyword_test => {
                func_code.code_type = .test_block;
            },
            .keyword_comptime => {
                if (func_code.code_type == .unkown and self.tokens[self.index + 1].token_type != .keyword_var) {
                    func_code.code_type = ._comptime;
                }
            },
            .l_brace => {
                if (func_code.code_type == .unkown) func_code.code_type = ._block;
                const token_pre = self.tokens[self.index - 1];
                if (token_pre.token_type == .identifier and func_code.code_type != .define_fn and func_code.code_type != .test_block) {
                    if (token_pre.text[0] >= 'A' and token_pre.text[0] <= 'Z') {
                        func_code.is_container = true;
                    } else {
                        self.error_func_code = func_code;
                        return CodeError.expected_capitalization_for_container_name;
                    }
                } else {
                    if (!func_code.is_container) {
                        try self.parseCode(&func_code);
                        try self.parseChildCode(&func_code);
                        break;
                    }
                }
            },
            .l_brace_r_brace => {
                if (func_code.code_type == .if_block) {
                    Console.print(">>>if_block find error token_type : {}\n");
                }
            },
            else => {},
        }
        self.index += 1;
    }
    return func_code;
}

fn parseCode(self: *CodeParse, func_code: *Code) CodeError!void {
    _ = self.parseCodeNode(func_code) catch |err| {
        self.error_func_code = func_code.*;
        return err;
    };
    func_code.end_token = self.index;
    self.index += 1;
}
fn parseChildCode(self: *CodeParse, func_code: *Code) CodeError!void {
    while (self.index < self.tokens.len - 1) {
        const child_code = try self.next(func_code);
        func_code.appendChildCodeList(child_code) catch {
            self.error_func_code = child_code;
            return CodeError.out_of_memory;
        };
        if (self.index < self.tokens.len and self.tokens[self.index].token_type == .r_brace) {
            self.index += 1;
            if (self.index < self.tokens.len and self.tokens[self.index].token_type == .semicolon) {
                self.index += 1;
            }
            break;
        }
    }
}
fn parseCodeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    switch (func_code.code_type) {
        .declare_param => {
            return try self.parseDeclareParameterCode(func_code);
        },
        .define_var => {
            return try self.parseDefineVarCode(func_code);
        },
        .assign => {
            return try self.parseAssignNode(func_code);
        },
        ._break => {
            return try self.parseBreakNode(func_code);
        },
        ._continue => {
            return try self.parseContinueNode(func_code);
        },
        ._unreachable => {
            return try self.parseUnreachableNode(func_code);
        },
        ._return => {
            return try self.parseReturnNode(func_code);
        },
        ._asm => {
            return try self.parseAsmCode(func_code);
        },
        ._code => {
            return try self.parseZigCode(func_code);
        },
        .call_fn => {
            return try self.parseCallFnCode(func_code);
        },
        ._try => {
            return try self.parseTryCode(func_code);
        },
        ._include => {
            return try self.parseIncludeCode(func_code);
        },
        ._block => {
            return try self.parseBlock(func_code);
        },
        .define_fn => {
            return try self.parseDefineFnBlock(func_code);
        },
        .if_block => {
            return try self.parseIfBlock(func_code);
        },
        .else_block => {
            return try self.parseElseBlock(func_code);
        },
        .else_if_block => {
            return try self.parseElseIfBlock(func_code);
        },
        .for_block => {
            return try self.parseForBlock(func_code);
        },
        .while_block => {
            return try self.parseWhileBlock(func_code);
        },
        .switch_block => {
            return try self.parseSwitchBlock(func_code);
        },
        .switch_case_block => {
            return try self.parseSwitchCaseBlock(func_code);
        },
        .test_block => {
            return try self.parseTestBlock(func_code);
        },
        ._defer => {
            return try self.parseDeferBlock(func_code);
        },
        ._errdefer => {
            return try self.parseErrDeferBlock(func_code);
        },
        ._comptime => {
            return try self.parseComptimeBlock(func_code);
        },
        .unkown => {
            return CodeError.unknow_code_type;
        },
        .invalid => {
            return CodeError.invalid_code_type;
        },
    }
}

fn getThisToken(self: *CodeParse, func_code: *Code) Token {
    return self.tokens[func_code.end_token];
}
fn getNextToken(self: *CodeParse, func_code: *Code) Token {
    const next_index = func_code.end_token + 1;
    if (next_index < self.tokens.len) {
        return self.tokens[next_index];
    } else {
        var token = Token.a(next_index);
        token.token_type = TokenType.invalid;
        return token;
    }
}

fn appendFuncCodeNode(func_code: *Code, node: Node) CodeError!NodeIndex {
    return func_code.appendNode(node) catch return CodeError.out_of_memory;
}
fn appendFuncCodeRootNode(func_code: *Code, node: Node) CodeError!NodeIndex {
    return func_code.appendRootNode(node) catch return CodeError.out_of_memory;
}
fn putFuncCodeArgMap(func_code: *Code, param_arg_index: NodeIndex, node_index: NodeIndex) CodeError!void {
    func_code.putArgNodeIndexMap(param_arg_index, node_index) catch return CodeError.out_of_memory;
}
fn skipOneToken(self: *CodeParse, func_code: *Code, token_type: TokenType) CodeError!TokenIndex {
    const token_index = func_code.end_token;
    if (self.getThisToken(func_code).token_type != token_type) {
        return CodeError.skip_one_invalid_token_type;
    }
    func_code.incEndToken();
    return token_index;
}

fn parseBreakNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const break_token_index = try self.skipOneToken(func_code, .keyword_break);
    const node = Node.a(break_token_index, ._break, null_node_index, null_node_index);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseContinueNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const continue_token_index = try self.skipOneToken(func_code, .keyword_continue);
    const node = Node.a(continue_token_index, ._continue, null_node_index, null_node_index);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseUnreachableNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const unreachable_token_index = try self.skipOneToken(func_code, .keyword_unreachable);
    const node = Node.a(unreachable_token_index, ._unreachable, null_node_index, null_node_index);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseReturnNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const return_token_index = try self.skipOneToken(func_code, .keyword_return);
    var result = null_node_index;
    if (self.getThisToken(func_code).token_type != .semicolon and self.getThisToken(func_code).token_type != .comma) {
        result = try self.parseExpressionNode(func_code);
    }
    const node = Node.a(return_token_index, ._return, null_node_index, result);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseAsmCode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const main_token = try self.skipOneToken(func_code, .keyword_asm);
    _ = try self.skipOneToken(func_code, .l_paren);
    const right_side = try self.parseExpressionNode(func_code);
    _ = try self.skipOneToken(func_code, .r_paren);
    if (self.getThisToken(func_code).token_type != .semicolon) {
        return CodeError.expected_semicolon;
    }
    const node = Node.a(main_token, .asm_simple, null_node_index, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseZigCode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const main_token = try self.skipOneToken(func_code, .keyword_code);
    _ = try self.skipOneToken(func_code, .l_paren);
    const right_side = try self.parseExpressionNode(func_code);
    _ = try self.skipOneToken(func_code, .r_paren);
    if (self.getThisToken(func_code).token_type != .semicolon) {
        return CodeError.expected_semicolon;
    }
    const node = Node.a(main_token, .code_simple, null_node_index, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseDeclareParameterCode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var node_index = try self.parseTypeDeclareNode(func_code);
    var param_node = try func_code.getNode(node_index);
    if (self.getThisToken(func_code).token_type == .equal) {
        const equal_token_index = try self.skipOneToken(func_code, .equal);
        const right_side = try self.parseExpressionNode(func_code);
        const node = Node.a(equal_token_index, .assign, node_index, right_side);
        node_index = try appendFuncCodeNode(func_code, node);
        param_node = try func_code.getNode(node_index);
    }
    _ = func_code.removeNode(node_index);
    _ = try appendFuncCodeRootNode(func_code, param_node);
    return node_index;
}

fn parseDefineVarCode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var node_index = null_node_index;
    var left_side = null_node_index;
    var this_token_type = self.getThisToken(func_code).token_type;
    while (this_token_type != .semicolon and this_token_type != .l_brace) {
        switch (this_token_type) {
            .keyword_pub => {
                const node = Node.a(func_code.end_token, .identifier, left_side, null_node_index);
                left_side = try appendFuncCodeNode(func_code, node);
                func_code.incEndToken();
            },
            .keyword_comptime => {
                const node = Node.a(func_code.end_token, .identifier, left_side, null_node_index);
                left_side = try appendFuncCodeNode(func_code, node);
                func_code.is_comptime = true;
                func_code.incEndToken();
            },
            .keyword_const, .keyword_var => {
                const main_token_index = func_code.end_token;
                func_code.incEndToken();
                const right_side = try self.parseAssignNode(func_code);
                const node = Node.a(main_token_index, .define_var, left_side, right_side);
                node_index = try appendFuncCodeRootNode(func_code, node);
            },
            else => {
                Console.print2("---------------parseDefineVarCode wrong func: {s}, token_type: {any}\n", .{ self.this_func.func_path, self.getThisToken(func_code).token_type });
                return CodeError.define_var_invalid_operator;
            },
        }
        this_token_type = self.getThisToken(func_code).token_type;
    }
    return node_index;
}
fn parseAssignNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const var_name = self.getThisToken(func_code).text;
    const first_letter = var_name[0];
    if (first_letter >= 'A' and first_letter <= 'Z') {
        func_code.is_capitalization = true;
    }
    var left_side = try self.parseTypeDeclareNode(func_code);
    while (self.getThisToken(func_code).token_type == .comma) {
        const comma_token = func_code.end_token;
        func_code.incEndToken();
        var right_side = null_node_index;
        if (self.getThisToken(func_code).token_type == .keyword_const or self.getThisToken(func_code).token_type == .keyword_var) {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right = try self.expectIdentifierNode(func_code);
            const node = Node.a(main_token, .identifier, null_node_index, right);
            right_side = try appendFuncCodeNode(func_code, node);
        } else {
            right_side = try self.expectIdentifierNode(func_code);
        }
        const node = Node.a(comma_token, .identifier, left_side, right_side);
        left_side = try appendFuncCodeNode(func_code, node);
    }
    const equal_token_index = func_code.end_token;
    func_code.incEndToken();
    const right_side = try self.parseExpressionNode(func_code);
    const node = Node.a(equal_token_index, .assign, left_side, right_side);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseTryCode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const node_index = try self.parseTryNode(func_code);
    const node = try func_code.getNode(node_index);
    _ = func_code.removeNode(node_index);
    return try appendFuncCodeRootNode(func_code, node);
}
fn parseTryNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const main_token = try self.skipOneToken(func_code, .keyword_try);
    var right_side = null_node_index;
    if (self.getThisToken(func_code).token_type == .keyword_comptime) {
        const comptime_token = func_code.end_token;
        func_code.incEndToken();
        right_side = try self.parseExpressionNode(func_code);
        const node = Node.a(comptime_token, .identifier, null_node_index, right_side);
        right_side = try appendFuncCodeNode(func_code, node);
        func_code.is_comptime = true;
    } else {
        right_side = try self.parseExpressionNode(func_code);
    }
    const node = Node.a(main_token, ._try, null_node_index, right_side);
    return try appendFuncCodeNode(func_code, node);
}

fn parseCallFnCode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const node_index = try self.parseExpressionNode(func_code);
    const node = try func_code.getNode(node_index);
    _ = func_code.removeNode(node_index);
    return try appendFuncCodeRootNode(func_code, node);
}
fn parseCallFnNode(self: *CodeParse, func_code: *Code, left_side: NodeIndex) CodeError!NodeIndex {
    const main_token = try self.skipOneToken(func_code, .l_paren);
    var arg_node_start = null_node_index;
    while (self.getThisToken(func_code).token_type != .r_paren) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        const arg_node_index = try self.parseExpressionNode(func_code);
        if (arg_node_start == null_node_index) {
            arg_node_start = arg_node_index;
        }
        try putFuncCodeArgMap(func_code, arg_node_start, arg_node_index);
    }
    const right_side_node = Node.a(func_code.end_token, .fn_arg, arg_node_start, null_node_index);
    const right_side = try appendFuncCodeNode(func_code, right_side_node);
    func_code.incEndToken();
    const node = Node.a(main_token, .call_fn, left_side, right_side);
    var node_index = try appendFuncCodeNode(func_code, node);
    if (self.getThisToken(func_code).token_type == .keyword_catch) {
        const catch_main_token = func_code.end_token;
        func_code.incEndToken();
        var catch_right_side = null_node_index;
        if (self.getThisToken(func_code).token_type != .l_brace) {
            catch_right_side = try self.parseCatchBlock(func_code);
        }
        const catch_node = Node.a(catch_main_token, ._catch, node_index, catch_right_side);
        node_index = try appendFuncCodeNode(func_code, catch_node);
    } else if (self.getThisToken(func_code).token_type != .semicolon) {
        node_index = try self.parsePeriodRightNode(func_code, node_index);
    }
    switch (self.getThisToken(func_code).token_type) {
        .identifier, .keyword_pub, .keyword_const, .keyword_var, .keyword_try, .keyword_break, .keyword_continue, .keyword_comptime, .keyword_code, .keyword_defer, .keyword_errdefer, .keyword_fn, .keyword_for, .keyword_if, .keyword_while, .keyword_switch, .keyword_include, .keyword_inline, .keyword_return, .keyword_test, .keyword_unreachable => {
            return CodeError.expected_semicolon;
        },
        else => {},
    }
    return node_index;
}

fn expectIdentifierNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    if (self.getThisToken(func_code).token_type != .identifier) {
        return CodeError.expected_identifier;
    }
    const identifier_token_index = func_code.end_token;
    const identifier_name = self.getThisToken(func_code).text;
    func_code.incEndToken();
    var identifier_node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .colon => {
            const node = Node.a(identifier_token_index, .identifier, null_node_index, null_node_index);
            identifier_node_index = try appendFuncCodeNode(func_code, node);
        },
        .period, .period_asterisk, .period_question => {
            const left_node = Node.a(identifier_token_index, .identifier, null_node_index, null_node_index);
            const left_side = try appendFuncCodeNode(func_code, left_node);
            identifier_node_index = try self.parsePeriodRightNode(func_code, left_side);
        },
        .l_bracket => {
            const left_node = Node.a(identifier_token_index, .identifier, null_node_index, null_node_index);
            const left_side = try appendFuncCodeNode(func_code, left_node);
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const array_access_node_index = try self.parseArrayAccessNode(func_code);
            const node = Node.a(main_token, .array_access, left_side, array_access_node_index);
            identifier_node_index = try appendFuncCodeNode(func_code, node);
        },
        .l_paren => {
            const first_letter = identifier_name[0];
            if (first_letter >= 'A' and first_letter <= 'Z') {
                return CodeError.expected_no_capitalization_for_function_name;
            } else {
                const node = Node.a(identifier_token_index, .identifier, null_node_index, null_node_index);
                identifier_node_index = try appendFuncCodeNode(func_code, node);
                identifier_node_index = try self.parseCallFnNode(func_code, identifier_node_index);
            }
        },
        else => {
            if (self.getThisToken(func_code).token_type == .l_brace and func_code.is_container) {
                const right_side = try self.parseFuncInitArgListNode(func_code);
                const func_init_node = Node.a(identifier_token_index, .func_init, null_node_index, right_side);
                identifier_node_index = try appendFuncCodeNode(func_code, func_init_node);
            } else {
                const node = Node.a(identifier_token_index, .identifier, null_node_index, null_node_index);
                identifier_node_index = try appendFuncCodeNode(func_code, node);
            }
        },
    }
    return identifier_node_index;
}

fn parseArrayAccessNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var left_side = try self.parseExpressionNode(func_code);
    var r_bracket_token_index: TokenIndex = 0;
    if (self.getThisToken(func_code).token_type == .ellipsis2) {
        const ellipsis2_token = func_code.end_token;
        func_code.incEndToken();
        const right_side = if (self.getThisToken(func_code).token_type != .r_bracket) try self.parseExpressionNode(func_code) else null_node_index;
        const node = Node.a(ellipsis2_token, .slice, left_side, right_side);
        left_side = try appendFuncCodeNode(func_code, node);
        r_bracket_token_index = try self.skipOneToken(func_code, .r_bracket);
    } else {
        r_bracket_token_index = try self.skipOneToken(func_code, .r_bracket);
    }
    var right_node_index = null_node_index;
    if (self.getThisToken(func_code).token_type != .semicolon) {
        right_node_index = try self.parsePeriodRightNode(func_code, right_node_index);
    }
    const node = Node.a(r_bracket_token_index, .array_access, left_side, right_node_index);
    return try appendFuncCodeNode(func_code, node);
}

fn parsePeriodRightNode(self: *CodeParse, func_code: *Code, node_index: NodeIndex) CodeError!NodeIndex {
    var right_node_index = null_node_index;
    const token = self.getThisToken(func_code);
    switch (token.token_type) {
        .l_bracket => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            right_node_index = try self.parseArrayAccessNode(func_code);
            const node = Node.a(main_token, .array_access, node_index, right_node_index);
            right_node_index = try appendFuncCodeNode(func_code, node);
        },
        .identifier => {
            right_node_index = try self.expectIdentifierNode(func_code);
        },
        .period_asterisk => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .deref, node_index, null_node_index);
            right_node_index = try appendFuncCodeNode(func_code, node);
            switch (self.getThisToken(func_code).token_type) {
                .period_asterisk, .period_question, .period => {
                    right_node_index = try self.parsePeriodRightNode(func_code, right_node_index);
                },
                else => {},
            }
        },
        .period_question => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .unwrap_optional, node_index, null_node_index);
            right_node_index = try appendFuncCodeNode(func_code, node);
            switch (self.getThisToken(func_code).token_type) {
                .period_asterisk, .period_question, .period => {
                    right_node_index = try self.parsePeriodRightNode(func_code, right_node_index);
                },
                else => {},
            }
        },
        .period => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .field_access, node_index, try self.expectIdentifierNode(func_code));
            right_node_index = try appendFuncCodeNode(func_code, node);
            switch (self.getThisToken(func_code).token_type) {
                .period_asterisk, .period_question, .period => {
                    right_node_index = try self.parsePeriodRightNode(func_code, right_node_index);
                },
                else => {},
            }
        },
        .keyword_break, .keyword_continue, .keyword_unreachable, .keyword_return => {
            return CodeError.expected_semicolon;
        },
        else => {
            right_node_index = node_index;
        },
    }
    return right_node_index;
}

fn parseExpressionNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    switch (self.getThisToken(func_code).token_type) {
        .keyword_if => return try self.parseIfElseLineNode(func_code),
        .keyword_return => return try self.parseReturnNode(func_code),
        .keyword_import => return try self.parseImportFuncNode(func_code),
        .keyword_enum, .keyword_union, .keyword_func, .keyword_error, .keyword_struct => return try self.parseContainerNode(func_code),
        .l_bracket => {
            if (self.getNextToken(func_code).token_type == .r_bracket) {
                return try self.parseTypeNode(func_code);
            } else {
                func_code.is_array_init = true;
                return try self.parseArrayInitNode(func_code);
            }
        },
        .asterisk, .question_mark, .keyword_fn, .keyword_align => return try self.parseTypeNode(func_code),
        else => return try self.expectOrNode(func_code),
    }
}

fn parseEmptyBlockNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    _ = self;
    const empty_node = Node.a(func_code.end_token, .empty_block, null_node_index, null_node_index);
    func_code.incEndToken();
    return try appendFuncCodeNode(func_code, empty_node);
}

fn parseArrayInitNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    if (self.getNextToken(func_code).token_type == .l_bracket) {
        const main_token = try self.skipOneToken(func_code, .l_bracket);
        var right_side = try self.parseExpressionNode(func_code);
        while (self.getThisToken(func_code).token_type == .r_bracket) {
            const node = Node.a(func_code.end_token, .array_init_value, null_node_index, right_side);
            right_side = try appendFuncCodeNode(func_code, node);
            func_code.incEndToken();
        }
        if (self.getThisToken(func_code).token_type == .comma) {
            if (self.getNextToken(func_code).token_type == .r_bracket) {
                func_code.incEndToken();
            } else {
                const comma_main_token = func_code.end_token;
                const left_side = right_side;
                func_code.incEndToken();
                right_side = try self.parseExpressionNode(func_code);
                const node = Node.a(comma_main_token, .array_init_comma, left_side, right_side);
                right_side = try appendFuncCodeNode(func_code, node);
            }
        }
        const node = Node.a(main_token, .array_init, null_node_index, right_side);
        return try appendFuncCodeNode(func_code, node);
    } else {
        var main_token = try self.skipOneToken(func_code, .l_bracket);
        var right_side = try self.parseArrayInitValueNode(func_code);
        var node = Node.a(main_token, .array_init, null_node_index, right_side);
        right_side = try appendFuncCodeNode(func_code, node);
        if (self.getThisToken(func_code).token_type == .comma) {
            if (self.getNextToken(func_code).token_type == .r_bracket) {
                func_code.incEndToken();
            } else {
                main_token = func_code.end_token;
                const left_side = right_side;
                func_code.incEndToken();
                right_side = try self.parseExpressionNode(func_code);
                node = Node.a(main_token, .array_init_comma, left_side, right_side);
                right_side = try appendFuncCodeNode(func_code, node);
            }
        }
        return right_side;
    }
}

fn parseArrayInitValueNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var array_value_start = null_node_index;
    while (self.getThisToken(func_code).token_type != .r_bracket) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        const array_value_node_index = try self.parseExpressionNode(func_code);
        if (array_value_start == null_node_index) {
            array_value_start = array_value_node_index;
        }
        try putFuncCodeArgMap(func_code, array_value_start, array_value_node_index);
    }
    const value_node = Node.a(func_code.end_token, .array_init_value, array_value_start, null_node_index);
    func_code.incEndToken();
    return try appendFuncCodeNode(func_code, value_node);
}

fn expectOrNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectAndNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .keyword_or => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectAndNode(func_code);
            const node = Node.a(main_token, .bool_or, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectAndNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectCompareNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .keyword_or => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectAndNode(func_code);
            const node = Node.a(main_token, .bool_or, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .keyword_and => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectCompareNode(func_code);
            const node = Node.a(main_token, .bool_and, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectCompareNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectBitOrNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .keyword_and => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectCompareNode(func_code);
            const node = Node.a(main_token, .bool_and, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .equal_equal, .bang_equal, .angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_right, .angle_bracket_right_equal => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectBitOrNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectBitOrNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectBitXorNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .equal_equal, .bang_equal, .angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_right, .angle_bracket_right_equal => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectBitOrNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .pipe => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectBitXorNode(func_code);
            const node = Node.a(main_token, .bit_or, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectBitXorNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectBitAndNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .pipe => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectBitXorNode(func_code);
            const node = Node.a(main_token, .bit_or, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .caret => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectBitAndNode(func_code);
            const node = Node.a(main_token, .bit_xor, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectBitAndNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectBitShiftNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .caret => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectBitAndNode(func_code);
            const node = Node.a(main_token, .bit_xor, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .ampersand => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectBitShiftNode(func_code);
            const node = Node.a(main_token, .bit_and, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectBitShiftNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectAddSubtractNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .ampersand => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_side = try self.expectBitShiftNode(func_code);
            const node = Node.a(main_token, .bit_and, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .angle_bracket_angle_bracket_left, .angle_bracket_angle_bracket_right => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectAddSubtractNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectAddSubtractNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectMulDivModNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .angle_bracket_angle_bracket_left, .angle_bracket_angle_bracket_right => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectAddSubtractNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .plus, .minus, .plus_plus => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectMulDivModNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectMulDivModNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.expectUnaryNode(func_code);
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .plus, .minus, .plus_plus => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectMulDivModNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .asterisk, .slash, .percent, .asterisk_asterisk, .pipe_pipe => {
            const main_token = func_code.end_token;
            const node_type = getNodeType(self.getThisToken(func_code).token_type);
            func_code.incEndToken();
            const right_side = try self.expectUnaryNode(func_code);
            const node = Node.a(main_token, node_type, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}

fn expectUnaryNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .minus, .bang, .tilde, .ampersand => {
            const main_token = func_code.end_token;
            var node_type = getNodeType(self.getThisToken(func_code).token_type);
            if (node_type == .sub) node_type = .negation;
            func_code.incEndToken();
            const right_side = try self.parseExpressionNode(func_code);
            const node = Node.a(main_token, node_type, null_node_index, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            const left_side = try self.parseExpressionValueNode(func_code);
            switch (self.getThisToken(func_code).token_type) {
                .asterisk, .slash, .percent, .asterisk_asterisk, .pipe_pipe => {
                    const main_token = func_code.end_token;
                    const node_type = getNodeType(self.getThisToken(func_code).token_type);
                    func_code.incEndToken();
                    const right_side = try self.expectUnaryNode(func_code);
                    const node = Node.a(main_token, node_type, left_side, right_side);
                    node_index = try appendFuncCodeNode(func_code, node);
                },
                else => {
                    node_index = left_side;
                },
            }
        },
    }
    return node_index;
}

fn parseExpressionValueNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var node_index = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .identifier => {
            node_index = try self.parseTypeDeclareNode(func_code);
        },
        .keyword_unreachable => {
            node_index = try self.parseUnreachableNode(func_code);
        },
        .keyword_try => {
            node_index = try self.parseTryNode(func_code);
        },
        .keyword_else => {
            const main_token = func_code.end_token;
            const node = Node.a(main_token, .identifier, null_node_index, null_node_index);
            node_index = try appendFuncCodeNode(func_code, node);
            func_code.incEndToken();
        },
        .period => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .field_access, null_node_index, try self.parseTypeDeclareNode(func_code));
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .keyword_error => {
            const error_token = func_code.end_token;
            const error_node = Node.a(error_token, .identifier, null_node_index, null_node_index);
            const error_node_index = try appendFuncCodeNode(func_code, error_node);
            func_code.incEndToken();
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .field_access, error_node_index, try self.expectIdentifierNode(func_code));
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .period_l_brace => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            var arg_node_start = null_node_index;
            while (self.getThisToken(func_code).token_type != .r_brace) {
                if (self.getThisToken(func_code).token_type == .comma) {
                    func_code.incEndToken();
                    continue;
                }
                const arg_node_index = try self.parseOneFuncInitArgNode(func_code);
                if (arg_node_start == null_node_index) {
                    arg_node_start = arg_node_index;
                }
                try putFuncCodeArgMap(func_code, arg_node_start, arg_node_index);
            }
            _ = try self.skipOneToken(func_code, .r_brace);
            const node = Node.a(main_token, .func_init_dot, null_node_index, arg_node_start);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .number_literal, .char_literal => {
            const node_type = if (self.getThisToken(func_code).token_type == .number_literal) NodeType.number_literal else NodeType.char_literal;
            const number_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(number_token, node_type, null_node_index, null_node_index);
            node_index = try appendFuncCodeNode(func_code, node);
            if (self.getThisToken(func_code).token_type == .ellipsis3) {
                const main_token = func_code.end_token;
                func_code.incEndToken();
                const right_side = try self.parseExpressionValueNode(func_code);
                const switch_range_node = Node.a(main_token, .switch_range, node_index, right_side);
                node_index = try appendFuncCodeNode(func_code, switch_range_node);
            }
        },
        .string_literal => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .string_literal, null_node_index, null_node_index);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .multiline_string_literal => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .multiline_string_literal, null_node_index, null_node_index);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        .l_paren => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const left_side = try self.parseExpressionNode(func_code);
            const token_index = try self.skipOneToken(func_code, .r_paren);
            const right_node = Node.a(token_index, .grouped_expression, null_node_index, null_node_index);
            const right_side = try appendFuncCodeNode(func_code, right_node);
            const node = Node.a(main_token, .grouped_expression, left_side, right_side);
            node_index = try appendFuncCodeNode(func_code, node);
            switch (self.getThisToken(func_code).token_type) {
                .period, .l_bracket => {
                    node_index = try self.parsePeriodRightNode(func_code, node_index);
                },
                else => {},
            }
        },
        .l_brace_r_brace => {
            node_index = try self.parseEmptyBlockNode(func_code);
        },
        .asterisk => {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const node = Node.a(main_token, .pointer_type, null_node_index, null_node_index);
            node_index = try appendFuncCodeNode(func_code, node);
        },
        else => {
            return CodeError.expected_identifier_value;
        },
    }
    return node_index;
}

fn parseIfElseLineNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    _ = try self.skipOneToken(func_code, .keyword_if);
    _ = try self.skipOneToken(func_code, .l_paren);
    var node: Node = undefined;
    const condition_node_index = try self.parseExpressionNode(func_code);
    const r_paren_token_index = try self.skipOneToken(func_code, .r_paren);
    const if_value_node_index = try self.parseExpressionNode(func_code);
    node = Node.a(r_paren_token_index, .if_else_line, condition_node_index, if_value_node_index);
    const left_side = try appendFuncCodeNode(func_code, node);
    const else_token_index = try self.skipOneToken(func_code, .keyword_else);
    const else_value_node_index = try self.parseExpressionNode(func_code);
    node = Node.a(else_token_index, .if_else_line, left_side, else_value_node_index);
    return try appendFuncCodeNode(func_code, node);
}

fn parseFuncInitArgListNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const main_token = try self.skipOneToken(func_code, .l_brace);
    var arg_node_start = null_node_index;
    while (self.getThisToken(func_code).token_type != .r_brace) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        const arg_node_index = try self.parseOneFuncInitArgNode(func_code);
        if (arg_node_start == null_node_index) {
            arg_node_start = arg_node_index;
        }
        try putFuncCodeArgMap(func_code, arg_node_start, arg_node_index);
    }
    _ = try self.skipOneToken(func_code, .r_brace);
    const field_node = Node.a(main_token, .func_init_arg_list, null_node_index, arg_node_start);
    return try appendFuncCodeNode(func_code, field_node);
}

fn parseOneFuncInitArgNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const left_side = try self.parseExpressionNode(func_code);
    if (self.getThisToken(func_code).token_type == .equal) {
        const main_token = func_code.end_token;
        func_code.incEndToken();
        const right_side = try self.parseExpressionNode(func_code);
        const field_node = Node.a(main_token, .func_init_arg, left_side, right_side);
        return try appendFuncCodeNode(func_code, field_node);
    } else {
        return left_side;
    }
}

fn parseCatchBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const current_token_type = self.getThisToken(func_code).token_type;
    if (current_token_type == .l_paren or current_token_type == .pipe) {
        func_code.incEndToken();
        const left_side = try self.expectIdentifierNode(func_code);
        const main_token = func_code.end_token;
        func_code.incEndToken();
        var right_side = null_node_index;
        switch (self.getThisToken(func_code).token_type) {
            .l_brace => {},
            .keyword_return => right_side = try self.parseReturnNode(func_code),
            .keyword_while => right_side = try self.parseWhileBlock(func_code),
            .keyword_switch => right_side = try self.parseSwitchBlock(func_code),
            .identifier => right_side = try self.parseExpressionNode(func_code),
            else => {
                return CodeError.catch_block_invalid_token_type;
            },
        }
        const node = Node.a(main_token, .catch_body, left_side, right_side);
        return try appendFuncCodeNode(func_code, node);
    } else {
        return try self.parseExpressionNode(func_code);
    }
}

fn parseWhileBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    if (self.getThisToken(func_code).token_type == .keyword_inline) {
        func_code.is_inline = true;
        func_code.incEndToken();
    }
    const while_token_index = try self.skipOneToken(func_code, .keyword_while);
    _ = try self.skipOneToken(func_code, .l_paren);
    const condition_items_index = try self.parseExpressionNode(func_code);
    var node: Node = undefined;
    if (self.getThisToken(func_code).token_type == .keyword_in) {
        func_code.incEndToken();
        const items_index = try self.parseExpressionNode(func_code);
        _ = try self.skipOneToken(func_code, .r_paren);
        node = Node.a(while_token_index, .while_block, condition_items_index, items_index);
    } else {
        _ = try self.skipOneToken(func_code, .r_paren);
        var condition_index = null_node_index;
        if (self.getThisToken(func_code).token_type == .pipe) {
            func_code.incEndToken();
            condition_index = try self.expectIdentifierNode(func_code);
            _ = try self.skipOneToken(func_code, .pipe);
        }
        node = Node.a(while_token_index, .while_block, condition_index, condition_items_index);
    }
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const l_brace_token_index = try self.skipOneToken(func_code, .l_brace);
    const node = Node.a(l_brace_token_index, ._block, null_node_index, null_node_index);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseDefineFnBlock(self: *CodeParse, func_code: *Code) !NodeIndex {
    var node_index = null_node_index;
    var left_side = null_node_index;
    while (func_code.end_token < self.index) {
        switch (self.getThisToken(func_code).token_type) {
            .keyword_pub => {
                const node = Node.a(func_code.end_token, .identifier, left_side, null_node_index);
                left_side = try appendFuncCodeNode(func_code, node);
                func_code.incEndToken();
            },
            .keyword_inline => {
                const node = Node.a(func_code.end_token, .identifier, left_side, null_node_index);
                left_side = try appendFuncCodeNode(func_code, node);
                func_code.is_inline = true;
                func_code.incEndToken();
            },
            .keyword_fn => {
                const main_token_index = func_code.end_token;
                func_code.incEndToken();
                const fn_proto_node_index = try self.parseFnProtoNode(func_code);
                const node = Node.a(main_token_index, .define_fn, left_side, fn_proto_node_index);
                node_index = try appendFuncCodeRootNode(func_code, node);
            },
            else => {
                return CodeError.define_fn_invalid_token_type;
            },
        }
    }
    return node_index;
}

fn parseFnProtoNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const fn_name = self.getThisToken(func_code).text;
    const first_letter = fn_name[0];
    if (first_letter >= 'A' and first_letter <= 'Z') {
        return CodeError.expected_no_capitalization_for_function_name;
    }
    const fn_name_token_index = func_code.end_token;
    func_code.incEndToken();
    _ = try self.skipOneToken(func_code, .l_paren);
    var param_node_start = null_node_index;
    while (self.getThisToken(func_code).token_type != .r_paren) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        var param_node_index = null_node_index;
        if (self.getThisToken(func_code).token_type == .keyword_comptime) {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_node = try self.parseTypeDeclareNode(func_code);
            const node = Node.a(main_token, ._comptime, null_node_index, right_node);
            param_node_index = try appendFuncCodeNode(func_code, node);
        } else {
            param_node_index = try self.parseTypeDeclareNode(func_code);
        }
        if (param_node_start == null_node_index) {
            param_node_start = param_node_index;
        }
        try putFuncCodeArgMap(func_code, param_node_start, param_node_index);
    }
    const param_node = Node.a(func_code.end_token, .fn_param, param_node_start, null_node_index);
    const fn_param = try appendFuncCodeNode(func_code, param_node);
    _ = try self.skipOneToken(func_code, .r_paren);
    if (func_code.end_token + 1 > self.index) {
        return CodeError.expected_fn_result;
    }
    const fn_result = try self.parseFnResultNode(func_code);
    const node = Node.a(fn_name_token_index, .fn_proto, fn_param, fn_result);
    return try appendFuncCodeNode(func_code, node);
}

fn parseFnResultNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var fn_result = null_node_index;
    const current_token_type = self.getThisToken(func_code).token_type;
    if (current_token_type == .keyword_align or current_token_type == .keyword_callconv or current_token_type == .bang or current_token_type == .question_mark or current_token_type == .asterisk or current_token_type == .l_bracket) {
        fn_result = try self.parseTypeNode(func_code);
    } else {
        fn_result = try self.parseExpressionNode(func_code);
        if (self.getThisToken(func_code).token_type == .bang) {
            fn_result = try self.parseErrorUnionTypeNode(func_code, fn_result);
        }
    }
    return fn_result;
}

fn parseTypeDeclareNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var node_index = try self.expectIdentifierNode(func_code);
    if (self.getThisToken(func_code).token_type == .colon) {
        const colon_token = func_code.end_token;
        func_code.incEndToken();
        const right_side = try self.parseTypeNode(func_code);
        const node = Node.a(colon_token, .type_decl, node_index, right_side);
        node_index = try appendFuncCodeNode(func_code, node);
    }
    return node_index;
}
fn parseTypeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var first_node_index = null_node_index;
    var left_side = null_node_index;
    var right_side = null_node_index;
    var token_type = self.getThisToken(func_code).token_type;
    while (func_code.end_token < self.index and token_type != .semicolon and token_type != .comma and token_type != .equal and token_type != .r_paren) {
        const main_token = func_code.end_token;
        switch (self.getThisToken(func_code).token_type) {
            .bang => right_side = try self.parseErrorUnionTypeNode(func_code, null_node_index),
            .question_mark => right_side = try self.parseOptionalTypeNode(func_code),
            .asterisk => right_side = try self.parsePointerTypeNode(func_code),
            .keyword_align => right_side = try self.parseAlignTypeNode(func_code),
            .keyword_callconv => {
                const callconv_token = func_code.end_token;
                func_code.incEndToken();
                _ = try self.skipOneToken(func_code, .l_paren);
                const arg_node_index = try self.parseExpressionNode(func_code);
                _ = try self.skipOneToken(func_code, .r_paren);
                const node = Node.a(callconv_token, .callconv_type, null_node_index, arg_node_index);
                right_side = try appendFuncCodeNode(func_code, node);
            },
            .keyword_const => {
                const const_token = func_code.end_token;
                func_code.incEndToken();
                if (self.getThisToken(func_code).token_type == .keyword_fn) {
                    right_side = try self.parseExpressionNode(func_code);
                } else {
                    right_side = try self.expectIdentifierNode(func_code);
                }
                const node = Node.a(const_token, .identifier, null_node_index, right_side);
                right_side = try appendFuncCodeNode(func_code, node);
            },
            .keyword_fn => right_side = try self.parseFnTypeNode(func_code),
            .l_bracket => right_side = try self.parseArrayTypeNode(func_code),
            .identifier => right_side = try self.expectIdentifierNode(func_code),
            else => {
                return CodeError.invalid_token_type;
            },
        }
        if (left_side == null_node_index) {
            left_side = right_side;
        } else {
            const node = Node.a(main_token, .type_expr, left_side, right_side);
            right_side = try appendFuncCodeNode(func_code, node);
            if (first_node_index == null_node_index) {
                first_node_index = right_side;
            }
            left_side = right_side;
        }
        token_type = self.getThisToken(func_code).token_type;
    }
    if (first_node_index == null_node_index) {
        first_node_index = right_side;
    }
    return first_node_index;
}

fn parseErrorUnionTypeNode(self: *CodeParse, func_code: *Code, left_side: NodeIndex) CodeError!NodeIndex {
    const bang_token_index = func_code.end_token;
    func_code.incEndToken();
    const current_token_type = self.getThisToken(func_code).token_type;
    var right_side = null_node_index;
    if (current_token_type == .question_mark) {
        right_side = try self.parseOptionalTypeNode(func_code);
    } else if (current_token_type == .asterisk) {
        right_side = try self.parsePointerTypeNode(func_code);
    } else if (current_token_type == .l_bracket) {
        right_side = try self.parseArrayTypeNode(func_code);
    } else {
        right_side = try self.expectIdentifierNode(func_code);
    }
    const node = Node.a(bang_token_index, .error_union, left_side, right_side);
    return try appendFuncCodeNode(func_code, node);
}

fn parseOptionalTypeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const question_token_index = func_code.end_token;
    func_code.incEndToken();
    const current_token_type = self.getThisToken(func_code).token_type;
    var right_side = null_node_index;
    if (current_token_type == .asterisk) {
        right_side = try self.parsePointerTypeNode(func_code);
    } else if (current_token_type == .l_bracket) {
        right_side = try self.parseArrayTypeNode(func_code);
    } else {
        right_side = try self.expectIdentifierNode(func_code);
    }
    const node = Node.a(question_token_index, .optional_type, null_node_index, right_side);
    return try appendFuncCodeNode(func_code, node);
}
fn parsePointerTypeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const pointer_token_index = func_code.end_token;
    func_code.incEndToken();
    const current_token_type = self.getThisToken(func_code).token_type;
    var right_side = null_node_index;
    if (current_token_type == .l_bracket) {
        right_side = try self.parseArrayTypeNode(func_code);
    } else if (current_token_type == .keyword_align) {
        right_side = try self.parseAlignTypeNode(func_code);
    } else {
        if (current_token_type == .keyword_const) {
            const const_token = func_code.end_token;
            func_code.incEndToken();
            if (self.getThisToken(func_code).token_type == .keyword_fn) {
                right_side = try self.parseExpressionNode(func_code);
            } else {
                right_side = try self.expectIdentifierNode(func_code);
            }
            const node = Node.a(const_token, .identifier, null_node_index, right_side);
            right_side = try appendFuncCodeNode(func_code, node);
        } else {
            right_side = try self.expectIdentifierNode(func_code);
        }
    }
    const node = Node.a(pointer_token_index, .pointer_type, null_node_index, right_side);
    return try appendFuncCodeNode(func_code, node);
}
fn parseArrayTypeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const main_token = func_code.end_token;
    func_code.incEndToken();
    const array_size_node_index = try self.parseArrayTypeSizeNode(func_code);
    var right_side = null_node_index;
    if (self.getThisToken(func_code).token_type == .keyword_const) {
        const const_token = func_code.end_token;
        func_code.incEndToken();
        if (self.getThisToken(func_code).token_type == .identifier) {
            right_side = try self.expectIdentifierNode(func_code);
        }
        const node = Node.a(const_token, .identifier, null_node_index, right_side);
        right_side = try appendFuncCodeNode(func_code, node);
    } else {
        right_side = try self.expectIdentifierNode(func_code);
    }
    const node = Node.a(main_token, .array_type, array_size_node_index, right_side);
    return try appendFuncCodeNode(func_code, node);
}

fn parseArrayTypeSizeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const token_type = self.getThisToken(func_code).token_type;
    if (token_type == .r_bracket) {
        const r_bracket_token_index = func_code.end_token;
        func_code.incEndToken();
        var right_node_index = null_node_index;
        if (self.getThisToken(func_code).token_type == .l_bracket) {
            func_code.incEndToken();
            right_node_index = try self.parseArrayTypeSizeNode(func_code);
        }
        const node = Node.a(r_bracket_token_index, .array_type, null_node_index, right_node_index);
        return try appendFuncCodeNode(func_code, node);
    } else {
        var left_side = null_node_index;
        if (token_type == .asterisk) {
            const node = Node.a(func_code.end_token, .pointer_type, null_node_index, null_node_index);
            left_side = try appendFuncCodeNode(func_code, node);
            func_code.incEndToken();
        } else if (token_type == .colon) {
            const colon_token_index = func_code.end_token;
            func_code.incEndToken();
            const right_node_index = try self.parseExpressionNode(func_code);
            const node = Node.a(colon_token_index, .slice_sentinel, null_node_index, right_node_index);
            left_side = try appendFuncCodeNode(func_code, node);
        } else if (self.getNextToken(func_code).token_type == .colon) {
            const left_node = Node.a(func_code.end_token, .identifier, null_node_index, null_node_index);
            const left_node_index = try appendFuncCodeNode(func_code, left_node);
            func_code.incEndToken();
            const colon_token_index = func_code.end_token;
            func_code.incEndToken();
            const right_node_index = try self.parseExpressionNode(func_code);
            const node = Node.a(colon_token_index, .slice_sentinel, left_node_index, right_node_index);
            left_side = try appendFuncCodeNode(func_code, node);
        } else {
            left_side = try self.parseExpressionNode(func_code);
        }
        const r_bracket_token_index = try self.skipOneToken(func_code, .r_bracket);
        var right_node_index = null_node_index;
        if (self.getThisToken(func_code).token_type == .l_bracket) {
            func_code.incEndToken();
            right_node_index = try self.parseArrayTypeSizeNode(func_code);
        }
        const node = Node.a(r_bracket_token_index, .array_type, left_side, right_node_index);
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseAlignTypeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const align_token = try self.skipOneToken(func_code, .keyword_align);
    _ = try self.skipOneToken(func_code, .l_paren);
    const arg_node_index = try self.parseExpressionNode(func_code);
    _ = try self.skipOneToken(func_code, .r_paren);
    const node = Node.a(align_token, .align_type, null_node_index, arg_node_index);
    return try appendFuncCodeNode(func_code, node);
}

fn parseFnTypeNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const fn_token_index = func_code.end_token;
    func_code.incEndToken();
    _ = try self.skipOneToken(func_code, .l_paren);
    var param_node_start = null_node_index;
    while (self.getThisToken(func_code).token_type != .r_paren) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        var param_node_index = null_node_index;
        const current_token_type = self.getThisToken(func_code).token_type;
        if (current_token_type == .keyword_comptime) {
            const main_token = func_code.end_token;
            func_code.incEndToken();
            const right_node = try self.parseTypeDeclareNode(func_code);
            const node = Node.a(main_token, ._comptime, null_node_index, right_node);
            param_node_index = try appendFuncCodeNode(func_code, node);
        } else if (current_token_type == .question_mark) {
            param_node_index = try self.parseOptionalTypeNode(func_code);
        } else if (current_token_type == .asterisk) {
            param_node_index = try self.parsePointerTypeNode(func_code);
        } else {
            param_node_index = try self.parseTypeDeclareNode(func_code);
        }
        if (param_node_start == null_node_index) {
            param_node_start = param_node_index;
        }
        try putFuncCodeArgMap(func_code, param_node_start, param_node_index);
    }
    const param_node = Node.a(func_code.end_token, .fn_param, param_node_start, null_node_index);
    const fn_param = try appendFuncCodeNode(func_code, param_node);
    _ = try self.skipOneToken(func_code, .r_paren);
    if (func_code.end_token + 1 >= self.index) {
        return CodeError.expected_fn_result;
    }
    const fn_result = try self.parseFnResultNode(func_code);
    const node = Node.a(fn_token_index, .fn_type, fn_param, fn_result);
    return try appendFuncCodeNode(func_code, node);
}

fn parseIfBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const if_token_index = try self.skipOneToken(func_code, .keyword_if);
    _ = try self.skipOneToken(func_code, .l_paren);
    var condition_node_index = try self.parseExpressionNode(func_code);
    _ = try self.skipOneToken(func_code, .r_paren);
    if (self.getThisToken(func_code).token_type == .pipe) {
        const pipe_token_index = try self.skipOneToken(func_code, .pipe);
        const arg_node_index = try self.expectIdentifierNode(func_code);
        _ = try self.skipOneToken(func_code, .pipe);
        const value_node = Node.a(pipe_token_index, .if_block, condition_node_index, arg_node_index);
        condition_node_index = try appendFuncCodeNode(func_code, value_node);
    }
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .keyword_continue => {
            const continue_token_index = try self.skipOneToken(func_code, .keyword_continue);
            const node2 = Node.a(continue_token_index, ._continue, null_node_index, null_node_index);
            right_side = try appendFuncCodeNode(func_code, node2);
        },
        .keyword_break => {
            const break_token_index = try self.skipOneToken(func_code, .keyword_break);
            const node2 = Node.a(break_token_index, ._break, null_node_index, null_node_index);
            right_side = try appendFuncCodeNode(func_code, node2);
        },
        .keyword_unreachable => {
            const unreachable_token_index = try self.skipOneToken(func_code, .keyword_unreachable);
            const node2 = Node.a(unreachable_token_index, ._unreachable, null_node_index, null_node_index);
            right_side = try appendFuncCodeNode(func_code, node2);
        },
        .keyword_return => {
            right_side = try self.parseReturnNode(func_code);
        },
        .keyword_try => {
            right_side = try self.parseTryNode(func_code);
        },
        .identifier => {
            right_side = try self.parseOneLineNode(func_code);
        },
        .l_brace_r_brace => {
            right_side = try self.parseEmptyBlockNode(func_code);
            self.index = func_code.end_token;
        },
        .l_brace => {
            if (self.getNextToken(func_code).token_type == .r_brace) {
                right_side = try self.parseEmptyBlockNode(func_code);
                self.index = func_code.end_token;
            }
        },
        else => {
            return CodeError.invalid_token_type;
        },
    }
    const node = Node.a(if_token_index, .if_block, condition_node_index, right_side);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseOneLineNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var is_assign = false;
    var i = func_code.end_token;
    while (i < self.index) {
        const token = self.tokens[i];
        switch (token.token_type) {
            .equal, .plus_equal, .minus_equal, .asterisk_equal, .slash_equal, .percent_equal, .ampersand_equal, .caret_equal, .pipe_equal, .angle_bracket_angle_bracket_left_equal, .angle_bracket_angle_bracket_right_equal => {
                is_assign = true;
            },
            else => {},
        }
        i += 1;
    }
    var node_index = null_node_index;
    if (is_assign) {
        node_index = try self.parseAssignNode(func_code);
    } else {
        node_index = try self.expectIdentifierNode(func_code);
    }
    return node_index;
}
fn parseElseBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const else_token_index = try self.skipOneToken(func_code, .keyword_else);
    if (self.getThisToken(func_code).token_type == .l_brace) {
        const node = Node.a(else_token_index, .else_block, null_node_index, null_node_index);
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return CodeError.expected_else_expression;
    }
}

fn parseElseIfBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const else_token_index = try self.skipOneToken(func_code, .keyword_else);
    const if_token_index = try self.skipOneToken(func_code, .keyword_if);
    _ = try self.skipOneToken(func_code, .l_paren);
    const condition_node_index = try self.parseExpressionNode(func_code);
    const if_node = Node.a(if_token_index, .if_block, null_node_index, condition_node_index);
    const if_node_index = try appendFuncCodeNode(func_code, if_node);
    _ = try self.skipOneToken(func_code, .r_paren);
    const node = Node.a(else_token_index, .else_if_block, null_node_index, if_node_index);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseSwitchBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    const switch_token_index = try self.skipOneToken(func_code, .keyword_switch);
    _ = try self.skipOneToken(func_code, .l_paren);
    const condition_node_index = try self.parseExpressionNode(func_code);
    const node = Node.a(switch_token_index, .switch_block, null_node_index, condition_node_index);
    _ = try self.skipOneToken(func_code, .r_paren);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseSwitchCaseBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var case_arg_start = null_node_index;
    while (self.getThisToken(func_code).token_type != .equal_angle_bracket_right) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        const expr_node_index = try self.parseExpressionValueNode(func_code);
        if (case_arg_start == null_node_index) {
            case_arg_start = expr_node_index;
        }
        try putFuncCodeArgMap(func_code, case_arg_start, expr_node_index);
    }
    const main_token = func_code.end_token;
    const left_node = Node.a(main_token, .case_arg, case_arg_start, null_node_index);
    const left_side = try appendFuncCodeNode(func_code, left_node);
    func_code.incEndToken();
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .l_brace => {
            func_code.incEndToken();
            self.index = func_code.end_token;
            try self.parseChildCode(func_code);
        },
        .l_brace_r_brace => {
            right_side = try self.parseEmptyBlockNode(func_code);
            self.index = func_code.end_token;
        },
        .keyword_continue => {
            right_side = try self.parseContinueNode(func_code);
            self.index = func_code.end_token;
        },
        .keyword_break => {
            right_side = try self.parseBreakNode(func_code);
            self.index = func_code.end_token;
        },
        .keyword_unreachable => {
            right_side = try self.parseUnreachableNode(func_code);
            self.index = func_code.end_token;
        },
        .keyword_return => {
            right_side = try self.parseReturnNode(func_code);
            self.index = func_code.end_token;
        },
        .keyword_try => {
            right_side = try self.parseTryNode(func_code);
            self.index = func_code.end_token;
        },
        .identifier => {
            var is_assign = false;
            var i = func_code.end_token;
            var token = self.tokens[i];
            while (token.token_type != .comma) {
                if (token.token_type == .equal) {
                    is_assign = true;
                }
                i += 1;
                token = self.tokens[i];
            }
            if (is_assign) {
                right_side = try self.parseAssignNode(func_code);
            } else {
                right_side = try self.expectIdentifierNode(func_code);
            }
            self.index = func_code.end_token;
        },
        else => {
            self.index = func_code.end_token;
            const child_code = try self.next(func_code);
            func_code.appendChildCodeList(child_code) catch {
                self.error_func_code = child_code;
                return CodeError.out_of_memory;
            };
        },
    }
    const node = Node.a(main_token, .switch_case_block, left_side, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseImportFuncNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    if (!func_code.is_capitalization) {
        return CodeError.expected_capitalization_for_container_name;
    }
    const import_token_index = func_code.end_token;
    func_code.incEndToken();
    _ = try self.skipOneToken(func_code, .l_paren);

    const import_path = self.getThisToken(func_code).text;
    var depend_func_path = import_path[1 .. import_path.len - 1];
    var depend_func_name: []const u8 = "";
    // Functree.func
    const functree_func_pos = String.indexOfStr(depend_func_path, "Functree.func");
    if (functree_func_pos == null) {
        if (!String.startWithStr(depend_func_path, "functree/")) {
            depend_func_path = self.getFuncFullPath(depend_func_path) catch return CodeError.out_of_memory;
        }
        depend_func_name = Func.getFuncFullName(self.memory, depend_func_path) catch return CodeError.out_of_memory;
    } else {
        depend_func_path = "Functree.func";
        depend_func_name = "Functree";
    }
    const last_period_pos = String.lastIndexOfStr(depend_func_name, ".");
    var func_file_name: []const u8 = undefined;
    if (last_period_pos == null) {
        func_file_name = depend_func_name;
    } else {
        func_file_name = depend_func_name[last_period_pos.? + 1 ..];
    }
    const first_letter = func_file_name[0];
    if (first_letter < 'A' or first_letter > 'Z') {
        return CodeError.expected_capitalization_for_container_name;
    }
    const depend_func = DependFunc.a(DependType.func_source, depend_func_name, depend_func_path, import_path);
    self.this_func.appendDependList(depend_func) catch return CodeError.out_of_memory;
    const right_side = try self.parseExpressionNode(func_code);
    _ = try self.skipOneToken(func_code, .r_paren);
    const node = Node.a(import_token_index, .import_func, null_node_index, right_side);
    return try appendFuncCodeNode(func_code, node);
}
fn parseIncludeCode(self: *CodeParse, func_code: *Code) !NodeIndex {
    const include_token_index = func_code.end_token;
    func_code.incEndToken();
    _ = try self.skipOneToken(func_code, .l_paren);

    var include_path = self.getThisToken(func_code).text;
    include_path = include_path[1 .. include_path.len - 1];
    const include_func_path = self.getFuncFullPath(include_path) catch return CodeError.out_of_memory;
    const include_func_name = Func.getFuncFullName(self.memory, include_func_path) catch return CodeError.out_of_memory;
    const depend_func = DependFunc.a(DependType.func_source, include_func_name, include_func_path, include_path);
    self.this_func.appendDependList(depend_func) catch return CodeError.out_of_memory;

    const right_node = Node.a(func_code.end_token, .string_literal, null_node_index, null_node_index);
    const right_side = try appendFuncCodeNode(func_code, right_node);
    const node = Node.a(include_token_index, .include_func, null_node_index, right_side);
    func_code.incEndToken();
    _ = try self.skipOneToken(func_code, .r_paren);
    return try appendFuncCodeRootNode(func_code, node);
}
fn getFuncFullPath(self: *CodeParse, import_or_include_path: []const u8) ![]const u8 {
    var last_slash_pos = String.lastIndexOfStr(self.this_func.func_path, "/");
    var this_func_dir_path = self.this_func.func_path[0..last_slash_pos.?];
    var relative_path = try String.copyStr(self.memory, import_or_include_path);
    var period_2_pos = String.indexOfStr(relative_path, "..");
    while (period_2_pos) |pos| {
        last_slash_pos = String.lastIndexOfStr(this_func_dir_path, "/");
        this_func_dir_path = this_func_dir_path[0..last_slash_pos.?];
        relative_path = relative_path[pos + 3 ..];
        period_2_pos = String.indexOfStr(relative_path, "..");
    }
    return try String.concatStr(self.memory, &.{ this_func_dir_path, "/", relative_path });
}

fn parseForBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const first_token_index = func_code.end_token;
    if (self.getThisToken(func_code).token_type == .keyword_inline) {
        func_code.is_inline = true;
        func_code.incEndToken();
    }
    const for_token_index = try self.skipOneToken(func_code, .keyword_for);
    _ = try self.skipOneToken(func_code, .l_paren);
    var item_start_index = null_node_index;
    while (self.getThisToken(func_code).token_type != .r_paren) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        var item_node_index = try self.parseExpressionNode(func_code);
        if (self.getThisToken(func_code).token_type == .ellipsis2) {
            const ellipsis2_token = func_code.end_token;
            func_code.incEndToken();
            var end_index = null_node_index;
            if (self.getThisToken(func_code).token_type != .r_paren and self.getThisToken(func_code).token_type != .comma) {
                end_index = try self.parseExpressionNode(func_code);
            }
            const item_node = Node.a(ellipsis2_token, .slice, item_node_index, end_index);
            item_node_index = try appendFuncCodeNode(func_code, item_node);
        }
        if (item_start_index == null_node_index) {
            item_start_index = item_node_index;
        }
        try putFuncCodeArgMap(func_code, item_start_index, item_node_index);
    }
    const item_node = Node.a(func_code.end_token, .fn_arg, item_start_index, null_node_index);
    item_start_index = try appendFuncCodeNode(func_code, item_node);
    _ = try self.skipOneToken(func_code, .r_paren);
    _ = try self.skipOneToken(func_code, .pipe);
    var value_start_index = null_node_index;
    while (self.getThisToken(func_code).token_type != .pipe) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        const value_node_index = try self.expectIdentifierNode(func_code);
        if (value_start_index == null_node_index) {
            value_start_index = value_node_index;
        }
        try putFuncCodeArgMap(func_code, value_start_index, value_node_index);
    }
    const value_node = Node.a(func_code.end_token, .fn_arg, value_start_index, null_node_index);
    value_start_index = try appendFuncCodeNode(func_code, value_node);
    const condition_node = Node.a(func_code.end_token, .for_block, item_start_index, value_start_index);
    const condition_node_index = try appendFuncCodeNode(func_code, condition_node);
    _ = try self.skipOneToken(func_code, .pipe);
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .keyword_try => {
            right_side = try self.parseTryNode(func_code);
        },
        .identifier => {
            right_side = try self.parseOneLineNode(func_code);
        },
        .l_brace => {},
        else => {
            return CodeError.invalid_token_type;
        },
    }
    const node = Node.a(for_token_index, .for_block, condition_node_index, right_side);
    if (first_token_index == func_code.start_token) {
        return try appendFuncCodeRootNode(func_code, node);
    } else {
        return try appendFuncCodeNode(func_code, node);
    }
}

fn parseTestBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const test_token_index = try self.skipOneToken(func_code, .keyword_test);
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .string_literal, .identifier => {
            right_side = try self.parseExpressionValueNode(func_code);
        },
        else => {},
    }
    const node = Node.a(test_token_index, .test_block, null_node_index, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseDeferBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const defer_token_index = try self.skipOneToken(func_code, .keyword_defer);
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .l_brace => {},
        else => {
            right_side = try self.parseExpressionNode(func_code);
        },
    }
    const node = Node.a(defer_token_index, ._defer, null_node_index, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseErrDeferBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const errdefer_token_index = try self.skipOneToken(func_code, .keyword_errdefer);
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .l_brace => {},
        else => {
            right_side = try self.parseExpressionNode(func_code);
        },
    }
    const node = Node.a(errdefer_token_index, ._errdefer, null_node_index, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseComptimeBlock(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    const comptime_token_index = try self.skipOneToken(func_code, .keyword_comptime);
    var right_side = null_node_index;
    switch (self.getThisToken(func_code).token_type) {
        .l_brace => {},
        else => {
            right_side = try self.parseExpressionNode(func_code);
        },
    }
    const node = Node.a(comptime_token_index, ._comptime, null_node_index, right_side);
    return try appendFuncCodeRootNode(func_code, node);
}

fn parseContainerNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var node: Node = undefined;
    if (self.getThisToken(func_code).token_type == .keyword_error and self.getNextToken(func_code).token_type == .period) {
        const error_token_index = try self.skipOneToken(func_code, .keyword_error);
        const left_node = Node.a(error_token_index, .identifier, null_node_index, null_node_index);
        const left_side = try appendFuncCodeNode(func_code, left_node);
        const main_token = func_code.end_token;
        func_code.incEndToken();
        const right_side = try self.expectIdentifierNode(func_code);
        node = Node.a(main_token, .field_access, left_side, right_side);
    } else {
        if (!func_code.is_capitalization and !func_code.is_fn) {
            return CodeError.expected_capitalization_for_container_name;
        }
        const container_token_index = func_code.end_token;
        func_code.incEndToken();
        var left_side = null_node_index;
        if (self.getThisToken(func_code).token_type == .l_paren) {
            func_code.incEndToken();
            left_side = try self.expectIdentifierNode(func_code);
            _ = try self.skipOneToken(func_code, .r_paren);
        }
        const right_side = try self.parseContainerFieldNode(func_code);
        func_code.incEndToken();
        node = Node.a(container_token_index, .container_decl, left_side, right_side);
    }
    return try appendFuncCodeNode(func_code, node);
}

fn parseContainerFieldNode(self: *CodeParse, func_code: *Code) CodeError!NodeIndex {
    var field_node_start = null_node_index;
    const main_token = try self.skipOneToken(func_code, .l_brace);
    while (self.getThisToken(func_code).token_type != .r_brace) {
        if (self.getThisToken(func_code).token_type == .comma) {
            func_code.incEndToken();
            continue;
        }
        var field_node_index = null_node_index;
        if (self.getThisToken(func_code).token_type == .l_bracket) {
            field_node_index = try self.parseArrayTypeNode(func_code);
        } else {
            field_node_index = try self.parseTypeDeclareNode(func_code);
            if (self.getThisToken(func_code).token_type == .equal) {
                const equal_token = func_code.end_token;
                func_code.incEndToken();
                const right_side = try self.parseExpressionNode(func_code);
                const field_node = Node.a(equal_token, .func_init_arg, field_node_index, right_side);
                field_node_index = try appendFuncCodeNode(func_code, field_node);
            }
        }
        if (field_node_start == null_node_index) {
            field_node_start = field_node_index;
        }
        try putFuncCodeArgMap(func_code, field_node_start, field_node_index);
    }
    const node = Node.a(main_token, .container_field, null_node_index, field_node_start);
    return try appendFuncCodeNode(func_code, node);
}

fn getNodeType(tokenType: TokenType) NodeType {
    switch (tokenType) {
        .equal_equal => return NodeType.equal_equal,
        .bang_equal => return NodeType.bang_equal,
        .angle_bracket_left => return NodeType.less_than,
        .angle_bracket_left_equal => return NodeType.less_or_equal,
        .angle_bracket_right => return NodeType.greater_than,
        .angle_bracket_right_equal => return NodeType.greater_or_equal,
        .angle_bracket_angle_bracket_left => return NodeType.shl,
        .angle_bracket_angle_bracket_right => return NodeType.shr,
        .plus => return NodeType.add,
        .plus_plus => return NodeType.array_cat,
        .minus => return NodeType.sub,
        .asterisk => return NodeType.mul,
        .slash => return NodeType.div,
        .percent => return NodeType.mod,
        .asterisk_asterisk => return NodeType.array_mult,
        .pipe_pipe => return NodeType.merge_error_sets,
        .bang => return NodeType.bool_not,
        .tilde => return NodeType.bit_not,
        .ampersand => return NodeType.address_of,
        else => return NodeType.unkown,
    }
}

const CodeParse = @This();
