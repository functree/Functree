const std = @import("std");
const builtin = @import("builtin");
const unicode = @import("std").unicode;
const Utf8Iterator = @import("std").unicode.Utf8Iterator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Func = @import("Func.zig");
const FuncVar = Func.FuncVar;
const FuncParam = Func.FuncParam;
const FuncFn = Func.FuncFn;
const FuncError = Func.Error;
const FuncErrorTable = Func.ErrorTable;
const Statement = Func.Statement;
const Token = Func.Token;
const TokenType = Func.TokenType;
const KeywordMap = Func.KeywordMap;
const TokenIndex = Func.TokenIndex;
const TokenState = Func.TokenState;
const CodeType = Func.CodeType;
const CodeNode = Func.CodeNode;
const NodeType = Func.NodeType;
const NodeIndex = Func.NodeIndex;
const DependFunc = Func.DependFunc;
const DependType = Func.DependType;

const Util = @import("Util.zig");
const Str = []const u8;

pub const root_node_index: NodeIndex = 0;
pub const null_node: NodeIndex = 0;
pub const Error = error{ParseError} || Allocator.Error || std.fs.Dir.OpenError;

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
/// Arena-allocated memory, mostly used during initialization. However, it can
/// be used for other things requiring the same lifetime as the Compilate.
arena: Allocator,

current_list_index: usize,
previous_utf8_char: Str,
next_utf8_char: Str,
current_line_no: usize,
current_column_no: usize,
current_func: Func,
current_token: Token,
current_token_state: TokenState,
current_token_index: TokenIndex,
errors: std.ArrayList(FuncError),
block_count: usize = 0,
pub const Parse = @This();
pub fn init(gpa: Allocator, arena: Allocator) Parse {
    const self = Parse{
        .gpa = gpa,
        .arena = arena,
        .errors = .empty,

        .current_list_index = 0,
        .previous_utf8_char = "",
        .next_utf8_char = "",
        .current_line_no = 1,
        .current_column_no = 0,
        .current_func = undefined,
        .current_token = undefined,
        .current_token_state = undefined,
        .current_token_index = 0,
    };
    return self;
}

pub fn deinit(self: *Parse) void {
    self.* = undefined;
}

pub fn parseFuncSourceCode(self: *Parse, func_path: Str) !Func {
    const func_name = try Parse.get_func_name(self.arena, func_path);
    const source_code_buffer = try readFileToBuffer(self.gpa, func_path);
    defer self.gpa.free(source_code_buffer);
    self.current_func = Func.init(self.arena, func_name, func_path);

    var source_utf8_view = unicode.Utf8View.init(source_code_buffer) catch unreachable;
    var source_code_iterator = source_utf8_view.iterator();
    var list: std.ArrayList([]u8) = .empty;
    defer {
        for (list.items) |item| {
            self.gpa.free(item);
        }
        list.deinit(self.gpa);
    }
    while (source_code_iterator.nextCodepointSlice()) |string| {
        try list.append(self.gpa, try self.gpa.dupe(u8, string));
    }
    try self.parseStatementAndToken(list, null);

    return self.current_func;
}
pub fn get_func_name(arena: Allocator, func_path: Str) !Str {
    const suffix_pos = std.mem.lastIndexOf(u8, func_path, ".");
    const func_name = try Util.copy(arena, func_path[0..suffix_pos.?]);
    std.mem.replaceScalar(u8, func_name, '/', '.');
    std.mem.replaceScalar(u8, func_name, '\\', '.');
    return func_name;
}
fn readFileToBuffer(gpa: Allocator, func_file_path: Str) ![]u8 {
    const f = std.fs.cwd().openFile(func_file_path, .{}) catch |err| {
        std.debug.print("{s}: read file error: {any}\n", .{ func_file_path, err });
        return err;
    };
    defer f.close(); // The file closes before we exit the function which happens before we work with the buffer.

    const f_len = try f.getEndPos();
    const buf = try gpa.alloc(u8, f_len);
    errdefer gpa.free(buf); // In case an error happens while reading

    _ = try f.readAll(buf);
    // const read_bytes = try f.readAll(buf);
    // std.debug.print("Read {} bytes\n", .{read_bytes});
    return buf;
}
fn currentStatementIsNotLegal(current_statement: *Statement) bool {
    if (current_statement.token_list.items.len > 0) {
        const last_token = current_statement.token_list.items[current_statement.token_list.items.len - 1];
        // std.debug.print("---checkCodeLine1 line_no = {d}, token_type='{any}'\n", .{ last_token.line_no, last_token.token_type });
        if (current_statement.code_type == .declare_param) {
            if (last_token.token_type != .comma) {
                return true;
            }
        } else if (last_token.token_type != .semicolon and last_token.token_type != .l_brace and last_token.token_type != .comma and last_token.token_type != .l_brace_r_brace) {
            return true;
        }
    }
    return false;
}
fn initCurrentStatement(self: *Parse, parent_statement: ?*Statement) Statement {
    const line_no = if (Util.isEql(self.next_utf8_char, "\n") or Util.isEql(self.next_utf8_char, "\r")) self.current_line_no + 1 else self.current_line_no;
    const scope: Str = if (parent_statement == null) "" else Util.concat(self.arena, &.{ parent_statement.?.scope, ".", parent_statement.?.name }) catch "";
    const current_statement = Statement.init(self.current_func.arena, line_no, scope, parent_statement);
    self.current_token = Token.init(.unkown, line_no, 1);
    self.current_token_state = .start;
    return current_statement;
}
fn appendCurrentStatement(self: *Parse, current_statement: Statement, parent_statement: ?*Statement) !void {
    if (parent_statement == null) {
        try self.current_func.appendStatementList(current_statement);
    } else {
        try parent_statement.?.appendChildStatementList(current_statement);
    }
}
fn notInMultilineStringLiteral(self: *Parse) bool {
    return self.current_token_state != .multiline_string_literal and self.current_token_state != .multiline_string_literal_end_1;
}
fn notInCommentStringLiteral(self: *Parse) bool {
    return self.current_token_state != .string_literal and self.current_token_state != .line_comment_start and self.notInMultilineStringLiteral();
}
fn statementNotFinished(self: *Parse) bool {
    return !Util.isEql(self.previous_utf8_char, ";") and !Util.isEql(self.previous_utf8_char, "{") and !Util.isEql(self.previous_utf8_char, "}");
}
fn parseStatementAndToken(self: *Parse, list: std.ArrayList([]u8), parent_statement: ?*Statement) !void {
    var seen_escape_digits: usize = undefined;

    const line_no = if (parent_statement == null) self.current_line_no else self.current_line_no + 1;
    const scope: Str = if (parent_statement == null) "" else Util.concat(self.arena, &.{ parent_statement.?.scope, ".", parent_statement.?.name }) catch "";
    var current_statement = Statement.init(self.current_func.arena, line_no, scope, parent_statement);
    self.current_token = Token.init(.unkown, line_no, self.current_column_no + 1);
    self.current_token_state = .start;
    while (self.current_list_index < list.items.len) {
        const utf8_char = list.items[self.current_list_index];
        self.current_list_index += 1;
        self.current_column_no += 1;
        self.next_utf8_char = "";
        if (self.current_list_index < list.items.len) self.next_utf8_char = list.items[self.current_list_index];

        if (Util.isEql(utf8_char, "\n") or Util.isEql(utf8_char, "\r")) {
            if (self.notInMultilineStringLiteral()) {
                if (Util.isEql(utf8_char, "\r") and Util.isEql(self.next_utf8_char, "\n")) {
                    self.current_list_index += 1;
                }
                if (Util.isEql(self.previous_utf8_char, " ")) {
                    // std.debug.print("nnnnnnnn{s},{s},  {d}\n", .{ self.current_token.text, self.previous_utf8_char, current_statement.token_list.items.len });
                    return self.fail(.invalid_space, &current_statement, self.current_token_index);
                }
                if (self.statementNotFinished() or self.current_token_state == .period_l_brace) {
                    //暂时不处理注释内容
                    if (self.current_token_state == .line_comment_start) {
                        // std.debug.print("current_token={s},{any}\n", .{ self.current_token.text, self.current_token.token_type });
                        if (current_statement.token_list.items.len == 0) {
                            current_statement.line_no += 1;
                        }
                        self.current_token.token_type = .unkown;
                        self.current_token.text = "";
                        self.current_token.line_no += 1;
                        self.current_token.column_no = 1;
                        self.current_token_state = .start;
                    } else {
                        try self.parseTokenFinished(&current_statement);
                    }
                    if (current_statement.code_type == .switch_case_block and Util.isEql(self.previous_utf8_char, ",")) {
                        // std.debug.print(">>>>>>>>>>>{s}  {any}  {any}\n", .{ self.current_token.text, self.current_token.token_type, current_statement.code_type });
                        _ = try self.parseStatementFinished(&current_statement);
                        try self.appendCurrentStatement(current_statement, parent_statement);
                        current_statement = self.initCurrentStatement(parent_statement);
                    }
                }
                //string_literal中不能换行
                if (self.current_token_state == .string_literal) {
                    return self.fail(.invalid_code, &current_statement, self.current_token_index);
                }
                //如果是空行
                if (Util.isEql(self.previous_utf8_char, "\n")) {
                    current_statement.line_no += 1;
                    self.current_token.line_no += 1;
                }
                //用于判断空行
                self.previous_utf8_char = "\n";
                self.current_line_no += 1;
                self.current_column_no = 0;
                continue;
            } else {
                if (Util.isEql(utf8_char, "\r") and Util.isEql(self.next_utf8_char, "\n")) {} else {
                    self.current_line_no += 1;
                }
            }
        }
        //token, not "'''abc'''"
        if ((Util.isEql(utf8_char, " ") or Util.isEql(utf8_char, "\t")) and self.notInCommentStringLiteral() and self.current_token_state != .char_literal) {
            if (self.current_token_state != .period_l_brace) {
                try self.parseTokenFinished(&current_statement);
            }
            self.previous_utf8_char = " ";
            continue;
        }
        if (Util.isEql(utf8_char, ",")) {
            if (current_statement.code_type == .declare_param and self.notInCommentStringLiteral()) {
                try self.parseTokenFinished(&current_statement);
                self.current_token.token_type = .comma;
                self.current_token.text = ",";
                self.current_token.column_no = self.current_column_no;
                try current_statement.appendTokenList(self.current_token);
                _ = try self.parseStatementFinished(&current_statement);
                try self.appendCurrentStatement(current_statement, parent_statement);
                current_statement = self.initCurrentStatement(parent_statement);
                continue;
            } else if (current_statement.code_type == .switch_case_block and current_statement.token_list.items[current_statement.token_list.items.len - 1].token_type == .l_brace_r_brace) {
                try self.parseTokenFinished(&current_statement);
                self.current_token.token_type = .comma;
                self.current_token.text = ",";
                self.current_token.column_no = self.current_column_no;
                try current_statement.appendTokenList(self.current_token);
                // std.debug.print("nnnnnnnn{s}  {any}\n", .{ self.current_token.text, self.current_token.token_type });
                _ = try self.parseStatementFinished(&current_statement);
                try self.appendCurrentStatement(current_statement, parent_statement);
                current_statement = self.initCurrentStatement(parent_statement);
                continue;
            }
        }
        //code_line end, not "ab;cd", not "'''abc'''"
        if (Util.isEql(utf8_char, ";") and self.notInCommentStringLiteral()) {
            try self.parseTokenFinished(&current_statement);
            self.current_token.token_type = .semicolon;
            self.current_token.text = ";";
            self.current_token.column_no = self.current_column_no;
            try current_statement.appendTokenList(self.current_token);
            // printFuncStatementTokenList(&current_statement);
            if (current_statement.code_type == CodeType.unkown) {
                std.debug.print(">>>>>>>>>>>>>>>>>CodeType.unkown--{any}\n", .{current_statement.code_type});
                return self.fail(.unknow_code_type, &current_statement, self.current_token_index);
            } else if (current_statement.code_type == CodeType.invalid) {
                std.debug.print(">>>>>>>>>>>>>>>>>CodeType.invalid--{any}\n", .{current_statement.code_type});
                return self.fail(.invalid_code_type, &current_statement, self.current_token_index);
            } else {
                _ = try self.parseStatementFinished(&current_statement);
                try self.appendCurrentStatement(current_statement, parent_statement);
                current_statement = self.initCurrentStatement(parent_statement);
            }
            self.previous_utf8_char = ";";
            continue;
        }
        //code_block start, not "{d}", not `u{0ab1Q}`, not `.{}`, not "'''abc'''"
        if (Util.isEql(utf8_char, "{") and self.current_token_state != .period and self.notInCommentStringLiteral() and self.current_token_state != .char_literal_unicode_escape_saw_u) {
            // return FuncName{} or = FuncName{}
            if (current_statement.code_type != CodeType.define_fn and current_statement.token_list.items.len > 0) {
                const first_letter = if (self.current_token.token_type != .unkown) self.current_token.text[0] else current_statement.token_list.items[current_statement.token_list.items.len - 1].text[0];
                if (first_letter >= 'A' and first_letter <= 'Z') {
                    current_statement.is_container = true;
                }
            }
            // if is "{}", and not FuncName{}
            if (!current_statement.is_container and Util.isEql(self.next_utf8_char, "}")) {
                if (self.current_token.token_type != .unkown) {
                    try self.parseTokenFinished(&current_statement);
                }
                self.current_token.token_type = .l_brace_r_brace;
                self.current_token.text = "{}";
                try current_statement.appendTokenList(self.current_token);
                self.current_list_index += 1;
                self.current_column_no += 1;
                self.current_token = Token.init(.unkown, self.current_line_no, self.current_column_no);
                self.current_token_state = .start;
                continue;
            }
            self.block_count += 1;
            try self.parseTokenFinished(&current_statement);
            self.current_token.token_type = .l_brace;
            self.current_token.text = "{";
            self.current_token.column_no = self.current_column_no;
            try current_statement.appendTokenList(self.current_token);
            if (!current_statement.is_container) {
                if (current_statement.code_type == CodeType.unkown) {
                    current_statement.code_type = ._block; // code_type = ._block
                } else if (current_statement.code_type == CodeType.invalid) {
                    return self.fail(.invalid_code_type, &current_statement, self.current_token_index);
                }
                _ = try self.parseStatementFinished(&current_statement);
                self.previous_utf8_char = "{";
                try self.parseStatementAndToken(list, &current_statement);
                try self.appendCurrentStatement(current_statement, parent_statement);
                // std.debug.print("_block current_statement child_list = {d}\n", .{current_statement.line_no});
                if (Util.isEql(self.previous_utf8_char, "}")) {
                    current_statement = self.initCurrentStatement(parent_statement);
                } else {
                    return self.fail(.expected_r_brace, &current_statement, self.current_token_index);
                }
            } else {
                self.current_token = Token.init(.unkown, self.current_line_no, self.current_column_no);
                self.current_token_state = .start;
                self.previous_utf8_char = "";
            }
            continue;
        }
        //code_block end, not `u{0ab1Q}`, not `.{}`
        if (Util.isEql(utf8_char, "}") and current_statement.state != .period_init_start and self.notInCommentStringLiteral() and self.current_token_state != .char_literal_unicode_escape) {
            if (current_statement.code_type == .unkown and Util.isEql(self.next_utf8_char, ";")) {
                self.current_list_index += 1;
            }
            self.previous_utf8_char = "}";
            if (!current_statement.is_container) {
                if (current_statement.code_type != CodeType.unkown) {
                    if (current_statement.code_type == CodeType.invalid) {
                        return self.fail(.invalid_code_type, &current_statement, self.current_token_index);
                    } else {
                        try self.appendCurrentStatement(current_statement, parent_statement);
                    }
                }
                break;
            } else {
                try self.parseTokenFinished(&current_statement);
                self.current_token.token_type = .r_brace;
                self.current_token.text = "}";
                self.current_token.column_no = self.current_column_no;
                try current_statement.appendTokenList(self.current_token);
                self.current_token = Token.init(.unkown, self.current_line_no, self.current_column_no);
                self.current_token_state = .start;
                if (current_statement.is_fn) {
                    current_statement.is_container = false;
                }
                continue;
            }
        }
        //utf8 codepoint
        const c = try unicode.utf8Decode(utf8_char);
        switch (self.current_token_state) {
            .start => {
                self.parseTokenStart(&current_statement, c);
            },

            .identifier => switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '_', '\u{4E00}'...'\u{9F00}' => {},
                '(' => {
                    try self.parseTokenFinished(&current_statement);
                    if (current_statement.code_type == .unkown) {
                        current_statement.code_type = .call_fn;
                    }
                    self.parseTokenStart(&current_statement, c);
                },
                ':' => {
                    //x:u32=1, not `ccc, var mod: usize = divmod(10, 3);`
                    if (current_statement.code_type == .unkown and !current_statement.have_const_var) {
                        current_statement.code_type = .declare_param;
                    }
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },

            .l_paren => {
                if (current_statement.code_type == .unkown) {
                    current_statement.code_type = .call_fn;
                }
                try self.parseTokenFinished(&current_statement);
                self.parseTokenStart(&current_statement, c);
            },
            .colon => {
                try self.parseTokenFinished(&current_statement);
                self.parseTokenStart(&current_statement, c);
            },
            .equal => switch (c) {
                '=' => {
                    self.current_token_state = .equal_equal;
                    self.current_token.token_type = .equal_equal; // ==
                },
                '>' => {
                    self.current_token_state = .equal_angle_bracket_right;
                    self.current_token.token_type = .equal_angle_bracket_right; // =>
                    current_statement.code_type = .switch_case_block;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .equal_angle_bracket_right => {
                try self.parseTokenFinished(&current_statement);
                self.parseTokenStart(&current_statement, c);
            },
            .bang => switch (c) {
                '=' => {
                    self.current_token_state = .bang_equal;
                    self.current_token.token_type = .bang_equal; // !=
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .angle_bracket_left => switch (c) {
                '<' => {
                    self.current_token_state = .angle_bracket_angle_bracket_left;
                    self.current_token.token_type = .angle_bracket_angle_bracket_left; // <<
                },
                '=' => {
                    self.current_token_state = .angle_bracket_left_equal;
                    self.current_token.token_type = .angle_bracket_left_equal; // <=
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .angle_bracket_right => switch (c) {
                '>' => {
                    self.current_token_state = .angle_bracket_angle_bracket_right;
                    self.current_token.token_type = .angle_bracket_angle_bracket_right; // >>
                },
                '=' => {
                    self.current_token_state = .angle_bracket_right_equal;
                    self.current_token.token_type = .angle_bracket_right_equal; // >=
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .period => switch (c) {
                '.' => {
                    self.current_token_state = .period_2;
                },
                '*' => {
                    self.current_token_state = .period_asterisk;
                    self.current_token.token_type = .period_asterisk; // .*
                },
                '?' => {
                    self.current_token_state = .period_question;
                    self.current_token.token_type = .period_question; // .?
                },
                '{' => {
                    self.current_token_state = .period_l_brace;
                    self.current_token.token_type = .period_l_brace; // .{
                    current_statement.state = .period_init_start;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .period_2 => switch (c) {
                '.' => {
                    self.current_token_state = .period_3;
                    self.current_token.token_type = .ellipsis3;
                },
                else => {
                    self.current_token.token_type = .ellipsis2;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .period_3 => switch (c) {
                '0'...'9', '\'' => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
                else => {
                    current_statement.code_type = .invalid;
                },
            },
            .period_asterisk => switch (c) {
                '*' => {
                    current_statement.code_type = .invalid;
                },
                else => {
                    self.current_token.token_type = .period_asterisk;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .period_question => switch (c) {
                '?' => {
                    current_statement.code_type = .invalid;
                },
                else => {
                    self.current_token.token_type = .period_question;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .period_l_brace => {
                try self.parseTokenFinished(&current_statement);
                self.parseTokenStart(&current_statement, c);
            },
            .period_r_brace => {
                try self.parseTokenFinished(&current_statement);
                self.parseTokenStart(&current_statement, c);
            },

            .plus => switch (c) {
                '+' => {
                    self.current_token_state = .plus_plus;
                    self.current_token.token_type = .plus_plus;
                },
                '=' => {
                    self.current_token_state = .plus_equal;
                    self.current_token.token_type = .plus_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .minus => switch (c) {
                '=' => {
                    self.current_token_state = .minus_equal;
                    self.current_token.token_type = .minus_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .asterisk => switch (c) {
                '*' => {
                    self.current_token_state = .asterisk_asterisk;
                    self.current_token.token_type = .asterisk_asterisk;
                },
                '=' => {
                    self.current_token_state = .asterisk_equal;
                    self.current_token.token_type = .asterisk_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .percent => switch (c) {
                '=' => {
                    self.current_token_state = .percent_equal;
                    self.current_token.token_type = .percent_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .ampersand => switch (c) {
                '=' => {
                    self.current_token_state = .ampersand_equal;
                    self.current_token.token_type = .ampersand_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .pipe => switch (c) {
                '|' => {
                    self.current_token_state = .pipe_pipe;
                    self.current_token.token_type = .pipe_pipe;
                },
                '=' => {
                    self.current_token_state = .pipe_equal;
                    self.current_token.token_type = .pipe_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .caret => switch (c) {
                '=' => {
                    self.current_token_state = .caret_equal;
                    self.current_token.token_type = .caret_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .question_mark, .l_bracket, .r_bracket, .comma, .r_paren, .plus_plus, .plus_equal, .minus_equal, .asterisk_asterisk, .asterisk_equal, .slash_equal, .percent_equal, .caret_equal, .ampersand_equal, .pipe_equal, .pipe_pipe, .bang_equal, .equal_equal, .tilde, .angle_bracket_angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_angle_bracket_right, .angle_bracket_right_equal => {
                try self.parseTokenFinished(&current_statement);
                self.parseTokenStart(&current_statement, c);
            },

            .int => switch (c) {
                '.' => self.current_token_state = .int_period,
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {},
                'e', 'E', 'p', 'P' => self.current_token_state = .int_exponent,
                else => {
                    self.current_token.token_type = .number_literal;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .int_exponent => switch (c) {
                '-', '+' => {
                    self.current_token_state = .float;
                },
                else => {
                    self.current_token_state = .int;
                },
            },
            .int_period => switch (c) {
                '.' => {
                    self.current_token.text = self.current_token.text[0 .. self.current_token.text.len - 1];
                    self.current_token.token_type = .number_literal;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                    self.current_token_state = .period_2;
                    self.current_token.text = try Util.concat(self.arena, &.{ self.current_token.text, "." });
                },
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    self.current_token_state = .float;
                },
                'e', 'E', 'p', 'P' => self.current_token_state = .float_exponent,
                else => {
                    self.current_token.token_type = .number_literal;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .float => switch (c) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {},
                'e', 'E', 'p', 'P' => self.current_token_state = .float_exponent,
                else => {
                    self.current_token.token_type = .number_literal;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .float_exponent => switch (c) {
                '-', '+' => self.current_token_state = .float,
                else => {
                    self.current_token_state = .float;
                },
            },

            .char_literal => switch (c) {
                0, '\n', 0xf8...0xff => {
                    current_statement.code_type = .invalid;
                },
                '\'' => { //'''multiline_string'''
                    self.current_token_state = .multiline_string_literal_start;
                },
                '\\' => {
                    self.current_token_state = .char_literal_backslash;
                },
                else => {
                    self.current_token_state = .char_literal_end;
                },
            },
            .char_literal_backslash => switch (c) {
                0, '\n' => {
                    current_statement.code_type = .invalid;
                },
                'x' => {
                    self.current_token_state = .char_literal_hex_escape;
                    seen_escape_digits = 0;
                },
                'u' => {
                    self.current_token_state = .char_literal_unicode_escape_saw_u;
                },
                else => {
                    self.current_token_state = .char_literal_end;
                },
            },
            .char_literal_hex_escape => switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    seen_escape_digits += 1;
                    if (seen_escape_digits == 2) {
                        self.current_token_state = .char_literal_end;
                    }
                },
                else => {
                    current_statement.code_type = .invalid;
                },
            },
            .char_literal_unicode_escape_saw_u => switch (c) {
                0 => {
                    current_statement.code_type = .invalid;
                },
                '{' => {
                    self.current_token_state = .char_literal_unicode_escape;
                },
                else => {
                    current_statement.code_type = .invalid;
                },
            },
            .char_literal_unicode_escape => switch (c) {
                0 => {
                    current_statement.code_type = .invalid;
                },
                '0'...'9', 'a'...'f', 'A'...'F' => {},
                '}' => {
                    self.current_token_state = .char_literal_end; // too many/few digits handled later
                },
                else => {
                    current_statement.code_type = .invalid;
                },
            },
            .char_literal_end => switch (c) {
                '.' => {
                    self.current_token.token_type = .char_literal;
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                    self.current_token_state = .period;
                },
                '\'' => {
                    self.current_token.token_type = .char_literal;
                },
                else => {
                    if (self.current_token.token_type == .char_literal) {
                        try self.parseTokenFinished(&current_statement);
                        self.parseTokenStart(&current_statement, c);
                    } else {
                        current_statement.code_type = .invalid;
                    }
                },
            },

            .string_literal => switch (c) {
                '\\' => {
                    self.current_token_state = .string_literal_backslash;
                },
                '"' => {
                    self.current_token_state = .string_literal_end;
                },
                0, '\n' => {
                    current_statement.code_type = .invalid;
                },
                else => {},
            },
            .string_literal_backslash => switch (c) {
                0, '\n' => {
                    current_statement.code_type = .invalid;
                },
                else => {
                    self.current_token_state = .string_literal;
                },
            },
            .string_literal_end => switch (c) {
                0, '\n' => {
                    current_statement.code_type = .invalid;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },

            .backslash => {},
            .multiline_string_literal_start => switch (c) {
                '\'' => {
                    self.current_token_state = .multiline_string_literal;
                    self.current_token.token_type = .multiline_string_literal;
                },
                else => {
                    current_statement.code_type = .invalid;
                },
            },
            .multiline_string_literal => switch (c) {
                '\'' => {
                    self.current_token_state = .multiline_string_literal_end_1;
                },
                else => {},
            },
            .multiline_string_literal_end_1 => switch (c) {
                '\'' => {
                    self.current_token_state = .multiline_string_literal_end_2;
                },
                else => {
                    self.current_token_state = .multiline_string_literal;
                },
            },
            .multiline_string_literal_end_2 => switch (c) {
                '\'' => {
                    self.current_token_state = .multiline_string_literal_end;
                },
                else => {
                    self.current_token_state = .multiline_string_literal;
                },
            },
            .multiline_string_literal_backslash => switch (c) {
                0 => {
                    current_statement.code_type = .invalid;
                },
                else => {
                    self.current_token_state = .multiline_string_literal;
                },
            },
            .multiline_string_literal_end => switch (c) {
                '\'' => {
                    current_statement.code_type = .invalid;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },

            .slash => switch (c) {
                '/' => {
                    self.current_token_state = .line_comment_start;
                },
                '=' => {
                    self.current_token_state = .slash_equal;
                    self.current_token.token_type = .slash_equal;
                },
                else => {
                    try self.parseTokenFinished(&current_statement);
                    self.parseTokenStart(&current_statement, c);
                },
            },
            .line_comment_start => {
                continue;
            },
            .doc_comment_start => switch (c) {
                '/' => {
                    self.current_token_state = .line_comment;
                },
                0, '\n' => {
                    self.current_token.token_type = .doc_comment;
                },
                '\t' => {
                    self.current_token_state = .doc_comment;
                    self.current_token.token_type = .doc_comment;
                },
                else => {
                    continue;
                },
            },
            .line_comment => switch (c) {
                0 => {},
                '\n' => {
                    self.current_token_state = .start;
                },
                '\t' => {},
                else => {},
            },
            .doc_comment => switch (c) {
                0, '\n' => {},
                '\t' => {},
                else => {},
            },
        }
        self.current_token.text = try Util.concat(self.arena, &.{ self.current_token.text, utf8_char });
        self.previous_utf8_char = utf8_char;
    }
}
fn parseTokenStart(self: *Parse, current_statement: *Statement, c: u21) void {
    self.current_token.column_no = self.current_column_no;
    switch (c) {
        'a'...'z', 'A'...'Z', '_', '\u{4E00}'...'\u{9F00}' => {
            self.current_token_state = .identifier;
            self.current_token.token_type = .identifier;
        },
        '0'...'9' => {
            self.current_token_state = .int;
            self.current_token.token_type = .number_literal;
        },
        '=' => {
            self.current_token_state = .equal;
            self.current_token.token_type = .equal;
        },
        '(' => {
            self.current_token_state = .l_paren;
            self.current_token.token_type = .l_paren;
        },
        ')' => {
            self.current_token_state = .r_paren;
            self.current_token.token_type = .r_paren;
        },
        '!' => {
            self.current_token_state = .bang;
            self.current_token.token_type = .bang;
        },
        '|' => {
            self.current_token_state = .pipe;
            self.current_token.token_type = .pipe;
        },
        ':' => {
            self.current_token_state = .colon;
            self.current_token.token_type = .colon;
        },
        '%' => {
            self.current_token_state = .percent;
            self.current_token.token_type = .percent;
        },
        '*' => {
            self.current_token_state = .asterisk;
            self.current_token.token_type = .asterisk;
        },
        '?' => {
            self.current_token_state = .question_mark;
            self.current_token.token_type = .question_mark;
        },
        '+' => {
            self.current_token_state = .plus;
            self.current_token.token_type = .plus;
        },
        '-' => {
            self.current_token_state = .minus;
            self.current_token.token_type = .minus;
        },
        '/' => {
            self.current_token_state = .slash;
            self.current_token.token_type = .slash;
        },
        '&' => {
            self.current_token_state = .ampersand;
            self.current_token.token_type = .ampersand;
        },
        '<' => {
            self.current_token_state = .angle_bracket_left;
            self.current_token.token_type = .angle_bracket_left;
        },
        '>' => {
            self.current_token_state = .angle_bracket_right;
            self.current_token.token_type = .angle_bracket_right;
        },
        '^' => {
            self.current_token_state = .caret;
            self.current_token.token_type = .caret;
        },
        '~' => {
            self.current_token.token_type = .tilde;
            self.current_token_state = .tilde;
        },
        ',' => {
            self.current_token.token_type = .comma;
            self.current_token_state = .comma;
        },
        '.' => {
            self.current_token_state = .period;
            self.current_token.token_type = .period;
        },
        '[' => {
            self.current_token_state = .l_bracket;
            self.current_token.token_type = .l_bracket;
        },
        ']' => {
            self.current_token_state = .r_bracket;
            self.current_token.token_type = .r_bracket;
        },
        '"' => {
            self.current_token_state = .string_literal;
            self.current_token.token_type = .string_literal;
        },
        '\'' => {
            if (self.current_token_state == .multiline_string_literal) {
                self.current_token_state = .multiline_string_literal_end_1;
            } else {
                self.current_token_state = .char_literal;
            }
        },
        ';' => {
            self.current_token.token_type = .semicolon;
        },
        '\\' => {
            self.current_token_state = .backslash;
        },
        '{' => {
            self.current_token.token_type = .l_brace;
        },
        '}' => {
            self.current_token.token_type = .r_brace;
            self.current_token_state = .period_r_brace;
            current_statement.state = .period_init_end;
        },
        else => {
            current_statement.code_type = .invalid;
        },
    }
}
fn parseTokenFinished(self: *Parse, current_statement: *Statement) Error!void {
    if (self.current_token.token_type != .unkown) {
        switch (self.current_token.token_type) {
            .identifier => {
                const token_type = KeywordMap.get(self.current_token.text);
                if (token_type != null) {
                    self.current_token.token_type = token_type.?;
                    if (self.current_token.token_type == .keyword_fn) {
                        current_statement.is_fn = true; // const ty = fn (numerator: u32, denominator: u32) struct { u32, u32 };
                    }
                    if (current_statement.code_type == .unkown) { //code_type is unkown
                        switch (self.current_token.token_type) {
                            .keyword_const, .keyword_var => {
                                current_statement.have_const_var = true;
                                if (current_statement.token_list.items.len < 2) {
                                    current_statement.code_type = .define_var; // code_type = .define_var
                                }
                            },
                            .keyword_fn => {
                                current_statement.code_type = .define_fn; // code_type = .define_fn
                            },
                            .keyword_if => {
                                current_statement.code_type = .if_block; // code_type = .if_block
                                current_statement.name = try std.fmt.allocPrint(self.arena, "{s}{d}", .{ "if$", self.block_count });
                            },
                            .keyword_else => {
                                current_statement.code_type = .else_block; // code_type = .else_block
                                current_statement.name = try std.fmt.allocPrint(self.arena, "{s}{d}", .{ "else$", self.block_count });
                            },
                            .keyword_for => {
                                current_statement.code_type = .for_block; // code_type = .for_block
                                current_statement.name = try std.fmt.allocPrint(self.arena, "{s}{d}", .{ "for$", self.block_count });
                            },
                            .keyword_while => {
                                current_statement.code_type = .while_block; // code_type = .while_block
                                current_statement.name = try std.fmt.allocPrint(self.arena, "{s}{d}", .{ "while$", self.block_count });
                            },
                            .keyword_switch => {
                                current_statement.code_type = .switch_block; // code_type = .switch_block
                                current_statement.name = try std.fmt.allocPrint(self.arena, "{s}{d}", .{ "switch$", self.block_count });
                            },
                            .keyword_break => {
                                current_statement.code_type = ._break; // code_type = ._break
                            },
                            .keyword_continue => {
                                current_statement.code_type = ._continue; // code_type = ._continue
                            },
                            .keyword_return => {
                                current_statement.code_type = ._return; // _return = ._return
                            },
                            .keyword_asm => {
                                current_statement.code_type = ._asm; // code_type = ._asm
                            },
                            .keyword_code => {
                                current_statement.code_type = .code; // code_type = .code
                            },
                            .keyword_test => {
                                current_statement.code_type = .test_block; // code_type = .test_block
                                current_statement.name = try std.fmt.allocPrint(self.arena, "{s}{d}", .{ "test$", self.block_count });
                            },
                            .keyword_try => {
                                current_statement.code_type = ._try; // code_type = ._try
                            },
                            .keyword_import => {
                                current_statement.code_type = .import; // code_type = .import
                            },
                            .keyword_defer => {
                                current_statement.code_type = ._defer; // code_type = ._defer
                            },
                            .keyword_errdefer => {
                                current_statement.code_type = ._errdefer; // code_type = ._errdefer
                            },
                            .keyword_comptime => {
                                current_statement.code_type = ._comptime; // code_type = ._comptime
                            },
                            else => {},
                        }
                    } else {
                        switch (self.current_token.token_type) {
                            .keyword_enum, .keyword_union, .keyword_func, .keyword_struct, .keyword_error => {
                                current_statement.is_container = true;
                            },
                            else => {},
                        }
                    }
                }
            },
            .equal, .plus_equal, .minus_equal, .asterisk_equal, .slash_equal, .percent_equal, .ampersand_equal, .caret_equal, .pipe_equal => {
                if (current_statement.code_type == .unkown) {
                    current_statement.code_type = .assign;
                }
            },
            else => {},
        }
        try current_statement.appendTokenList(self.current_token);
        // std.debug.print(">>>>>>>>>>>text={s}, token_type={any}, code_type={any}\n", .{ self.current_token.text, self.current_token.token_type, current_statement.code_type });
        self.current_token = Token.init(.unkown, self.current_line_no, self.current_column_no);
        self.current_token_state = .start;
    }
}

fn incTokenIndex(self: *Parse) void {
    self.current_token_index += 1;
}
fn decTokenIndex(self: *Parse) void {
    if (self.current_token_index > 0) {
        self.current_token_index -= 1;
    }
}
fn getCurrentToken(self: *Parse, current_statement: *Statement) Token {
    return current_statement.token_list.items[self.current_token_index];
}
fn getNextToken(self: *Parse, current_statement: *Statement) Token {
    return current_statement.token_list.items[self.current_token_index + 1];
}
fn parseStatementFinished(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    // printFuncStatementTokenList(current_statement);
    // std.debug.print(">>>>>>>>>>>{s}  {any}\n", .{ current_statement.name, current_statement.code_type });
    if (currentStatementIsNotLegal(current_statement)) {
        return self.fail(.invalid_code, current_statement, self.current_token_index);
    }
    switch (current_statement.code_type) {
        .declare_param => {
            return try self.parseDeclareParameterNode(current_statement);
        },
        .define_var => {
            return try self.parseDefineVarStatement(current_statement);
        },
        .assign => {
            self.current_token_index = 0;
            return try self.parseAssignNode(current_statement);
        },
        ._break => {
            return try self.parseBreakStatement(current_statement);
        },
        ._continue => {
            return try self.parseContinueStatement(current_statement);
        },
        ._return => {
            return try self.parseReturnStatement(current_statement);
        },
        // `asm(rhs)`
        ._asm => {
            return try self.parseAsmStatement(current_statement);
        },
        // `code(rhs)`
        .code => {
            return try self.parseZigStatement(current_statement);
        },
        .call_fn => {
            return try self.parseCallFnStatement(current_statement);
        },
        ._try => {
            return try self.parseTryStatement(current_statement);
        },
        .import => {
            return try self.parseImportStatement(current_statement);
        },

        // block,
        ._block => {
            return try self.parseBlock(current_statement);
        },
        .define_fn => {
            return try self.parseDefineFnBlock(current_statement);
        },
        // .define_func => {},
        .if_block => {
            self.current_token_index = 0;
            return try self.parseIfBlock(current_statement);
        },
        .else_block => {
            return try self.parseElseBlock(current_statement);
        },
        .for_block => {
            self.current_token_index = 0;
            return try self.parseForBlock(current_statement);
        },
        .while_block => {
            self.current_token_index = 0;
            return try self.parseWhileBlock(current_statement);
        },
        .switch_block => {
            self.current_token_index = 0;
            return try self.parseSwitchBlock(current_statement);
        },
        .switch_case_block => {
            return try self.parseSwitchCaseBlock(current_statement);
        },
        .test_block => {
            return try self.parseTestBlock(current_statement);
        },
        ._defer => {
            return try self.parseDeferBlock(current_statement);
        },
        ._errdefer => {
            return try self.parseErrDeferBlock(current_statement);
        },
        ._comptime => {
            return try self.parseComptimeBlock(current_statement);
        },

        .unkown => {
            return self.fail(.unknow_code_type, current_statement, self.current_token_index);
        },
        .invalid => {
            return self.fail(.invalid_code_type, current_statement, self.current_token_index);
        },
    }
}
fn parseBreakStatement(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'break'
    const break_token_index = try self.skipOneToken(current_statement, .keyword_break);
    const node = CodeNode.init(break_token_index, ._break, null_node, null_node);
    return try current_statement.appendRootNode(node);
}
fn parseContinueStatement(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'continue'
    const continue_token_index = try self.skipOneToken(current_statement, .keyword_continue);
    const node = CodeNode.init(continue_token_index, ._continue, null_node, null_node);
    return try current_statement.appendRootNode(node);
}
fn parseReturnStatement(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'return'
    const return_token_index = try self.skipOneToken(current_statement, .keyword_return);
    var result = null_node;
    if (current_statement.token_list.items.len > 2) {
        result = try self.parseExpressionNode(current_statement);
    }
    const node = CodeNode.init(return_token_index, ._return, null_node, result);
    return try current_statement.appendRootNode(node);
}
fn parseReturnNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //main_token is 'return'
    const return_token_index = try self.skipOneToken(current_statement, .keyword_return);
    var result = null_node;
    if (current_statement.token_list.items.len > 2) {
        result = try self.parseExpressionNode(current_statement);
    }
    const node = CodeNode.init(return_token_index, ._return, null_node, result);
    return try current_statement.appendNode(node);
}
fn parseIfElseLineNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    _ = try self.skipOneToken(current_statement, .keyword_if);
    _ = try self.skipOneToken(current_statement, .l_paren);
    var node: CodeNode = undefined;
    const condition_node_index = try self.parseExpressionNode(current_statement);
    const r_paren_token_index = try self.skipOneToken(current_statement, .r_paren);
    const if_value_node_index = try self.parseExpressionNode(current_statement);
    node = CodeNode.init(r_paren_token_index, .if_else_line, condition_node_index, if_value_node_index);
    const left_side = try current_statement.appendNode(node);

    //main_token is 'else'
    const else_token_index = try self.skipOneToken(current_statement, .keyword_else);
    const else_value_node_index = try self.parseExpressionNode(current_statement);

    node = CodeNode.init(else_token_index, .if_else_line, left_side, else_value_node_index);
    return try current_statement.appendNode(node);
}
fn parseBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is '{'
    const l_brace_token_index = try self.skipOneToken(current_statement, .l_brace);
    const node = CodeNode.init(l_brace_token_index, ._block, null_node, null_node);
    return try current_statement.appendRootNode(node);
}
fn parseDefineFnBlock(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    var node_index = null_node;
    var left_side = null_node;
    while (self.current_token_index < current_statement.token_list.items.len - 1) {
        switch (self.getCurrentToken(current_statement).token_type) {
            .keyword_pub => {
                const node = CodeNode.init(self.current_token_index, .identifier, left_side, null_node);
                left_side = try current_statement.appendNode(node);
                current_statement.is_pub = true;
                self.incTokenIndex();
            },
            .keyword_inline => {
                const node = CodeNode.init(self.current_token_index, .identifier, left_side, null_node);
                left_side = try current_statement.appendNode(node);
                current_statement.is_inline = true;
                self.incTokenIndex();
            },
            .keyword_fn => {
                const main_token_index = self.current_token_index;
                self.incTokenIndex();
                //right_side is 'fn_proto'
                const fn_proto_node_index = try self.parseFnProtoNode(current_statement);
                //main_token is fn
                const node = CodeNode.init(main_token_index, .define_fn, left_side, fn_proto_node_index);
                node_index = try current_statement.appendRootNode(node);
            },
            else => {
                std.debug.print("---------------parseDefineFnBlock wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
                return self.fail(.invalid_token_type, current_statement, self.current_token_index);
            },
        }
    }
    return node_index;
}
fn parseFnProtoNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //function_name is no capitalization
    const fn_name = self.getCurrentToken(current_statement).text;
    const first_letter = fn_name[0];
    if (first_letter >= 'A' and first_letter <= 'Z') {
        return self.fail(.expected_no_capitalization_for_function_name, current_statement, self.current_token_index);
    }
    const fn_name_token_index = self.current_token_index;
    self.incTokenIndex();
    _ = try self.skipOneToken(current_statement, .l_paren);
    current_statement.name = try Util.concat(self.arena, &.{ "fn$", fn_name });
    var param_node_start = null_node;
    while (self.getCurrentToken(current_statement).token_type != .r_paren) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        var param_node_index = null_node;
        if (self.getCurrentToken(current_statement).token_type == .keyword_comptime) {
            // `fn f(comptime param_name:type)`. main_token is 'comptime'. lhs is comptime, rhs is param_name
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_node = try self.expectIdentifierNode(current_statement);
            const node = CodeNode.init(main_token, ._comptime, null_node, right_node);
            param_node_index = try current_statement.appendNode(node);
        } else {
            param_node_index = try self.expectIdentifierNode(current_statement);
        }
        if (param_node_start == null_node) {
            param_node_start = param_node_index;
        }
        try current_statement.putArgNodeIndexMap(param_node_start, param_node_index);
    }
    //left_side is start index in statement.arg_node_index_map key, right_side is not use
    const param_node = CodeNode.init(self.current_token_index, .fn_param, param_node_start, null_node);
    const fn_param = try current_statement.appendNode(param_node);
    _ = try self.skipOneToken(current_statement, .r_paren);
    if (self.current_token_index + 1 >= current_statement.token_list.items.len) {
        return self.fail(.expected_fn_result, current_statement, self.current_token_index);
    }
    const fn_result = try self.parseFnResultNode(current_statement);
    //main_token is fn_name, `fn_name (lhs) rhs`
    const node = CodeNode.init(fn_name_token_index, .fn_proto, fn_param, fn_result);
    return try current_statement.appendNode(node);
}
fn parseFnResultNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var fn_result = null_node;
    const current_token_type = self.getCurrentToken(current_statement).token_type;
    if (current_token_type == .keyword_align or current_token_type == .keyword_callconv or current_token_type == .bang or current_token_type == .question_mark or current_token_type == .asterisk or current_token_type == .l_bracket) {
        //`algin(rhs)`, `callconv(rhs)`, !?*rhs, `?rhs`, `*rhs`, `[lhs]rhs`
        fn_result = try self.parseTypeNode(current_statement);
    } else {
        fn_result = try self.parseExpressionNode(current_statement);
        if (self.getCurrentToken(current_statement).token_type == .bang) {
            // `lhs!rhs`. main_token is the `!`.
            fn_result = try self.parseErrorUnionTypeNode(current_statement, fn_result);
        }
    }
    return fn_result;
}
fn parseErrorUnionTypeNode(self: *Parse, current_statement: *Statement, left_side: NodeIndex) Error!NodeIndex {
    const bang_token_index = self.current_token_index;
    self.incTokenIndex();
    const current_token_type = self.getCurrentToken(current_statement).token_type;
    var right_side = null_node;
    if (current_token_type == .question_mark) {
        right_side = try self.parseOptionalTypeNode(current_statement);
    } else if (current_token_type == .asterisk) {
        right_side = try self.parsePointerTypeNode(current_statement);
    } else if (current_token_type == .l_bracket) {
        right_side = try self.parseArrayTypeNode(current_statement);
    } else {
        right_side = try self.expectIdentifierNode(current_statement);
    }
    // `lhs!rhs`. main_token is the `!`.
    const node = CodeNode.init(bang_token_index, .error_union, left_side, right_side);
    return try current_statement.appendNode(node);
}
fn parsePointerTypeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const pointer_token_index = self.current_token_index;
    self.incTokenIndex();
    const current_token_type = self.getCurrentToken(current_statement).token_type;
    var right_side = null_node;
    if (current_token_type == .l_bracket) {
        right_side = try self.parseArrayTypeNode(current_statement);
    } else if (current_token_type == .keyword_align) {
        right_side = try self.parseAlignTypeNode(current_statement);
    } else {
        if (current_token_type == .keyword_const) {
            const const_token = self.current_token_index;
            self.incTokenIndex();
            if (self.getCurrentToken(current_statement).token_type == .keyword_fn) {
                right_side = try self.parseExpressionNode(current_statement);
            } else {
                right_side = try self.expectIdentifierNode(current_statement);
            }
            const node = CodeNode.init(const_token, .identifier, null_node, right_side);
            right_side = try current_statement.appendNode(node);
        } else {
            right_side = try self.expectIdentifierNode(current_statement);
        }
    }
    const node = CodeNode.init(pointer_token_index, .pointer_type, null_node, right_side);
    return try current_statement.appendNode(node);
}
fn parseOptionalTypeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const question_token_index = self.current_token_index;
    self.incTokenIndex();
    const current_token_type = self.getCurrentToken(current_statement).token_type;
    var right_side = null_node;
    if (current_token_type == .asterisk) {
        right_side = try self.parsePointerTypeNode(current_statement);
    } else if (current_token_type == .l_bracket) {
        right_side = try self.parseArrayTypeNode(current_statement);
    } else {
        right_side = try self.expectIdentifierNode(current_statement);
    }
    const node = CodeNode.init(question_token_index, .optional_type, null_node, right_side);
    return try current_statement.appendNode(node);
}
fn parseArrayTypeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //main_token is '['
    const main_token = self.current_token_index;
    self.incTokenIndex();
    const array_size_node_index = try self.parseArrayTypeSizeNode(current_statement);
    var right_side = null_node;
    if (self.getCurrentToken(current_statement).token_type == .keyword_const) {
        const const_token = self.current_token_index;
        self.incTokenIndex();
        if (self.getCurrentToken(current_statement).token_type == .identifier) {
            right_side = try self.expectIdentifierNode(current_statement);
        }
        const node = CodeNode.init(const_token, .identifier, null_node, right_side);
        right_side = try current_statement.appendNode(node);
    } else {
        right_side = try self.expectIdentifierNode(current_statement);
    }
    //`[lhs]rhs`
    const node = CodeNode.init(main_token, .array_type, array_size_node_index, right_side);
    return try current_statement.appendNode(node);
}
fn parseArrayTypeSizeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const token_type = self.getCurrentToken(current_statement).token_type;
    if (token_type == .r_bracket) {
        const r_bracket_token_index = self.current_token_index;
        self.incTokenIndex();
        var right_node_index = null_node;
        if (self.getCurrentToken(current_statement).token_type == .l_bracket) {
            self.incTokenIndex();
            right_node_index = try self.parseArrayTypeSizeNode(current_statement);
        }
        // `[]`. main_token is the `]`, array_size is undefined
        const node = CodeNode.init(r_bracket_token_index, .array_type, null_node, right_node_index);
        return try current_statement.appendNode(node);
    } else {
        var left_side = null_node;
        // [*]i32
        if (token_type == .asterisk) {
            const node = CodeNode.init(self.current_token_index, .identifier, null_node, null_node);
            left_side = try current_statement.appendNode(node);
            self.incTokenIndex();
        } else {
            left_side = try self.parseExpressionNode(current_statement);
        }
        const r_bracket_token_index = try self.skipOneToken(current_statement, .r_bracket);
        var right_node_index = null_node;
        if (self.getCurrentToken(current_statement).token_type == .l_bracket) {
            self.incTokenIndex();
            right_node_index = try self.parseArrayTypeSizeNode(current_statement);
        }
        const node = CodeNode.init(r_bracket_token_index, .array_type, left_side, right_node_index);
        return try current_statement.appendNode(node);
    }
}
fn parseFnTypeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const fn_token_index = self.current_token_index;
    self.incTokenIndex();
    _ = try self.skipOneToken(current_statement, .l_paren);

    var param_node_start = null_node;
    while (self.getCurrentToken(current_statement).token_type != .r_paren) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        var param_node_index = null_node;
        const current_token_type = self.getCurrentToken(current_statement).token_type;
        if (current_token_type == .keyword_comptime) {
            // `fn (comptime param_name:type)`. main_token is 'comptime'. lhs is comptime, rhs is param_name
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_node = try self.expectIdentifierNode(current_statement);
            const node = CodeNode.init(main_token, ._comptime, null_node, right_node);
            param_node_index = try current_statement.appendNode(node);
        } else if (current_token_type == .question_mark) {
            param_node_index = try self.parseOptionalTypeNode(current_statement);
        } else if (current_token_type == .asterisk) {
            param_node_index = try self.parsePointerTypeNode(current_statement);
        } else {
            param_node_index = try self.expectIdentifierNode(current_statement);
        }
        if (param_node_start == null_node) {
            param_node_start = param_node_index;
        }
        try current_statement.putArgNodeIndexMap(param_node_start, param_node_index);
    }
    //left_side is start index in statement.arg_node_index_map key, right_side is not use
    const param_node = CodeNode.init(self.current_token_index, .fn_param, param_node_start, null_node);
    const fn_param = try current_statement.appendNode(param_node);
    _ = try self.skipOneToken(current_statement, .r_paren);
    if (self.current_token_index + 1 >= current_statement.token_list.items.len) {
        return self.fail(.expected_fn_result, current_statement, self.current_token_index);
    }
    const fn_result = try self.parseFnResultNode(current_statement);
    //main_token is fn, `fn (lhs) rhs`
    const node = CodeNode.init(fn_token_index, .fn_type, fn_param, fn_result);
    return try current_statement.appendNode(node);
}
fn parseAlignTypeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //align(8), main_token is 'align'
    const align_token = try self.skipOneToken(current_statement, .keyword_align);
    _ = try self.skipOneToken(current_statement, .l_paren);
    const arg_node_index = try self.parseExpressionNode(current_statement);
    _ = try self.skipOneToken(current_statement, .r_paren);

    const node = CodeNode.init(align_token, .align_type, null_node, arg_node_index);
    return try current_statement.appendNode(node);
}
fn parseTypeNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var first_node_index = null_node;
    var left_side = null_node;
    var right_side = null_node;
    var token_type = self.getCurrentToken(current_statement).token_type;
    while (self.current_token_index < current_statement.token_list.items.len - 1 and token_type != .semicolon and token_type != .comma and token_type != .equal and token_type != .r_paren) {
        const main_token = self.current_token_index;
        switch (self.getCurrentToken(current_statement).token_type) {
            .bang => right_side = try self.parseErrorUnionTypeNode(current_statement, null_node),
            .question_mark => right_side = try self.parseOptionalTypeNode(current_statement),
            .asterisk => right_side = try self.parsePointerTypeNode(current_statement),
            .keyword_align => right_side = try self.parseAlignTypeNode(current_statement),
            .keyword_callconv => {
                const callconv_token = self.current_token_index;
                self.incTokenIndex();
                _ = try self.skipOneToken(current_statement, .l_paren);
                const arg_node_index = try self.parseExpressionNode(current_statement);
                _ = try self.skipOneToken(current_statement, .r_paren);
                //main_token is 'callconv'，left_side is not use
                const node = CodeNode.init(callconv_token, .callconv_type, null_node, arg_node_index);
                right_side = try current_statement.appendNode(node);
            },
            .keyword_const => {
                const const_token = self.current_token_index;
                self.incTokenIndex();
                if (self.getCurrentToken(current_statement).token_type == .keyword_fn) {
                    right_side = try self.parseExpressionNode(current_statement);
                } else {
                    right_side = try self.expectIdentifierNode(current_statement);
                }
                const node = CodeNode.init(const_token, .identifier, null_node, right_side);
                right_side = try current_statement.appendNode(node);
            },
            .keyword_fn => right_side = try self.parseFnTypeNode(current_statement),
            .l_bracket => right_side = try self.parseArrayTypeNode(current_statement),
            .identifier => right_side = try self.expectIdentifierNode(current_statement),
            else => {
                std.debug.print("---------------parseTypeNode wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
                unreachable;
            },
        }
        if (left_side == null_node) {
            left_side = right_side;
        } else {
            const node = CodeNode.init(main_token, .type_expr, left_side, right_side);
            right_side = try current_statement.appendNode(node);
            if (first_node_index == null_node) {
                first_node_index = right_side;
            }
            left_side = right_side;
        }
        token_type = self.getCurrentToken(current_statement).token_type;
    }
    if (first_node_index == null_node) {
        first_node_index = right_side;
    }
    return first_node_index;
}
fn parseContainerNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var node: CodeNode = undefined;
    if (self.getCurrentToken(current_statement).token_type == .keyword_error and self.getNextToken(current_statement).token_type == .period) {
        const error_token_index = try self.skipOneToken(current_statement, .keyword_error);
        const left_node = CodeNode.init(error_token_index, .identifier, null_node, null_node);
        const left_side = try current_statement.appendNode(left_node);
        const main_token = self.current_token_index;
        self.incTokenIndex();
        const right_side = try self.expectIdentifierNode(current_statement);
        //main_token is period, `error.Valid`, lhs is `error`, rhs is `Valid`
        node = CodeNode.init(main_token, .field_access, left_side, right_side);
    } else {
        if (!current_statement.is_capitalization and !current_statement.is_fn) {
            return self.fail(.expected_capitalization_for_container_name, current_statement, self.current_token_index);
        }
        const container_token_index = self.current_token_index;
        self.incTokenIndex();
        var left_side = null_node;
        if (self.getCurrentToken(current_statement).token_type == .l_paren) {
            self.incTokenIndex();
            left_side = try self.expectIdentifierNode(current_statement);
            _ = try self.skipOneToken(current_statement, .r_paren);
        }
        const right_side = try self.parseContainerFieldNode(current_statement);
        self.incTokenIndex();
        //main_token is enum or union or func(struct): enum(lhs){rhs}, union(lhs){rhs}, func{rhs}
        node = CodeNode.init(container_token_index, .container_decl, left_side, right_side);
    }
    return try current_statement.appendNode(node);
}
fn parseContainerFieldNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var field_node_start = null_node;
    const main_token = try self.skipOneToken(current_statement, .l_brace);
    while (self.getCurrentToken(current_statement).token_type != .r_brace) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        var field_node_index = null_node;
        if (self.getCurrentToken(current_statement).token_type == .l_bracket) {
            field_node_index = try self.parseArrayTypeNode(current_statement);
        } else {
            field_node_index = try self.expectIdentifierNode(current_statement);
            if (self.getCurrentToken(current_statement).token_type == .equal) {
                const equal_token = self.current_token_index;
                self.incTokenIndex();
                const right_side = try self.parseExpressionNode(current_statement);
                //param_name: type = values, main_token is '=', lhs is identifier node, rhs is expression
                const field_node = CodeNode.init(equal_token, .func_init_arg, field_node_index, right_side);
                field_node_index = try current_statement.appendNode(field_node);
            }
        }
        if (field_node_start == null_node) {
            field_node_start = field_node_index;
        }
        try current_statement.putArgNodeIndexMap(field_node_start, field_node_index);
    }
    // }
    //right_side is start index in statement.arg_node_index_map key，left_side is not use
    const field_node = CodeNode.init(main_token, .container_field, null_node, field_node_start);
    return try current_statement.appendNode(field_node);
}
fn parseFuncInitArgListNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const main_token = try self.skipOneToken(current_statement, .l_brace);
    var arg_node_start = null_node;
    while (self.getCurrentToken(current_statement).token_type != .r_brace) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        if (self.getCurrentToken(current_statement).token_type == .period) {
            self.incTokenIndex();
        }
        const arg_node_index = try self.parseOneFuncInitArgNode(current_statement);
        if (arg_node_start == null_node) {
            arg_node_start = arg_node_index;
        }
        try current_statement.putArgNodeIndexMap(arg_node_start, arg_node_index);
    }
    _ = try self.skipOneToken(current_statement, .r_brace);
    //right_side is start index in statement.arg_node_index_map key，left_side is not use
    const field_node = CodeNode.init(main_token, .func_init_arg, null_node, arg_node_start);
    return try current_statement.appendNode(field_node);
}
fn parseOneFuncInitArgNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.parseExpressionNode(current_statement);
    if (self.getCurrentToken(current_statement).token_type == .equal) {
        const main_token = self.current_token_index;
        self.incTokenIndex();
        const right_side = try self.parseExpressionNode(current_statement);
        //.param_name=values, main_token is '=', lhs is identifier node, rhs is expression
        const field_node = CodeNode.init(main_token, .func_init_arg, left_side, right_side);
        return try current_statement.appendNode(field_node);
    } else { //is a tuple
        return left_side;
    }
}
fn parseIfBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const first_token_index = self.current_token_index;
    //main_token is 'if'
    const if_token_index = try self.skipOneToken(current_statement, .keyword_if);
    _ = try self.skipOneToken(current_statement, .l_paren);
    var node: CodeNode = undefined;
    const condition_node_index = try self.parseExpressionNode(current_statement);
    _ = try self.skipOneToken(current_statement, .r_paren);
    //not '{'
    if (self.getCurrentToken(current_statement).token_type != .l_brace) {
        var right_side = null_node;
        switch (self.getCurrentToken(current_statement).token_type) {
            .keyword_continue => {
                //main_token is 'continue'
                const continue_token_index = try self.skipOneToken(current_statement, .keyword_continue);
                const node2 = CodeNode.init(continue_token_index, ._continue, null_node, null_node);
                right_side = try current_statement.appendNode(node2);
            },
            .keyword_break => {
                //main_token is 'break'
                const break_token_index = try self.skipOneToken(current_statement, .keyword_break);
                const node2 = CodeNode.init(break_token_index, ._break, null_node, null_node);
                right_side = try current_statement.appendNode(node2);
            },
            .keyword_return => {
                right_side = try self.parseReturnNode(current_statement);
            },
            .keyword_try => {
                right_side = try self.parseTryNode(current_statement);
            },
            .identifier => {
                var is_assign = false;
                var i = self.current_token_index;
                while (i < current_statement.token_list.items.len) {
                    const token = current_statement.token_list.items[i];
                    if (token.token_type == .equal) {
                        is_assign = true;
                    }
                    i += 1;
                }
                if (is_assign) {
                    right_side = try self.parseAssignNode(current_statement);
                } else {
                    right_side = try self.expectIdentifierNode(current_statement);
                }
            },
            else => {
                unreachable;
            },
        }
        node = CodeNode.init(if_token_index, .if_block, condition_node_index, right_side);
    } else {
        node = CodeNode.init(if_token_index, .if_block, null_node, condition_node_index);
    }
    if (first_token_index == 0) {
        return try current_statement.appendRootNode(node);
    } else {
        return try current_statement.appendNode(node);
    }
}
fn parseElseBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'else'
    const else_token_index = try self.skipOneToken(current_statement, .keyword_else);
    if (self.getCurrentToken(current_statement).token_type == .keyword_if) {
        const if_token_index = try self.skipOneToken(current_statement, .keyword_if);
        _ = try self.skipOneToken(current_statement, .l_paren);
        const condition_node_index = try self.parseExpressionNode(current_statement);
        const if_node = CodeNode.init(if_token_index, .if_block, null_node, condition_node_index);
        const if_node_index = try current_statement.appendNode(if_node);
        _ = try self.skipOneToken(current_statement, .r_paren);
        const node = CodeNode.init(else_token_index, .else_block, null_node, if_node_index);
        return try current_statement.appendRootNode(node);
    } else if (self.getCurrentToken(current_statement).token_type == .l_brace) {
        const node = CodeNode.init(else_token_index, .else_block, null_node, null_node);
        return try current_statement.appendRootNode(node);
    } else {
        return self.fail(.expected_if_expression, current_statement, self.current_token_index);
    }
}
fn parseForBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const first_token_index = self.current_token_index;
    if (self.getCurrentToken(current_statement).token_type == .keyword_inline) {
        current_statement.is_inline = true;
        self.incTokenIndex();
    }
    //main_token is 'for'
    const for_token_index = try self.skipOneToken(current_statement, .keyword_for);
    _ = try self.skipOneToken(current_statement, .l_paren);
    const value_items_index = try self.parseExpressionNode(current_statement);
    var node: CodeNode = undefined;
    const current_token_type = self.getCurrentToken(current_statement).token_type;
    if (current_token_type == .keyword_in) {
        self.incTokenIndex();
        const items_node_index = try self.parseExpressionNode(current_statement);
        _ = try self.skipOneToken(current_statement, .r_paren);
        node = CodeNode.init(for_token_index, .for_block, value_items_index, items_node_index);
    } else if (current_token_type == .comma) {
        self.incTokenIndex();
        try current_statement.putArgNodeIndexMap(value_items_index, value_items_index);
        while (self.getCurrentToken(current_statement).token_type != .r_paren) {
            if (self.getCurrentToken(current_statement).token_type == .comma) {
                self.incTokenIndex();
                continue;
            }
            var arg_node_index = try self.parseExpressionNode(current_statement);
            if (self.getCurrentToken(current_statement).token_type == .ellipsis2) {
                const ellipsis2_token = self.current_token_index;
                self.incTokenIndex();
                var value_end_index = null_node;
                if (self.getCurrentToken(current_statement).token_type != .r_paren and self.getCurrentToken(current_statement).token_type != .comma) {
                    value_end_index = try self.parseExpressionNode(current_statement);
                }
                const items_node = CodeNode.init(ellipsis2_token, .slice, arg_node_index, value_end_index);
                arg_node_index = try current_statement.appendNode(items_node);
            }
            try current_statement.putArgNodeIndexMap(value_items_index, arg_node_index);
        }
        //main_token is ')'，left_side is start index in statement.arg_node_index_map key，right_side is not use
        const items_node = CodeNode.init(self.current_token_index, .fn_arg, value_items_index, null_node);
        const items_node_index = try current_statement.appendNode(items_node);
        _ = try self.skipOneToken(current_statement, .r_paren);
        _ = try self.skipOneToken(current_statement, .pipe);
        var arg_node_start = null_node;
        while (self.getCurrentToken(current_statement).token_type != .pipe) {
            if (self.getCurrentToken(current_statement).token_type == .comma) {
                self.incTokenIndex();
                continue;
            }
            const arg_node_index = try self.expectIdentifierNode(current_statement);
            if (arg_node_start == null_node) {
                arg_node_start = arg_node_index;
            }
            try current_statement.putArgNodeIndexMap(arg_node_start, arg_node_index);
        }
        //main_token is '|'，left_side is start index in statement.arg_node_index_map key，right_side is not use
        const value_node = CodeNode.init(self.current_token_index, .fn_arg, arg_node_start, null_node);
        const value_node_index = try current_statement.appendNode(value_node);
        _ = try self.skipOneToken(current_statement, .pipe);
        node = CodeNode.init(for_token_index, .for_block, value_node_index, items_node_index);
    } else if (current_token_type == .ellipsis2) {
        const ellipsis2_token = self.current_token_index;
        self.incTokenIndex();
        const value_end_index = try self.parseExpressionNode(current_statement);
        _ = try self.skipOneToken(current_statement, .r_paren);
        const items_node = CodeNode.init(ellipsis2_token, .slice, value_items_index, value_end_index);
        const items_node_index = try current_statement.appendNode(items_node);
        _ = try self.skipOneToken(current_statement, .pipe);
        const value_node_index = try self.expectIdentifierNode(current_statement);
        _ = try self.skipOneToken(current_statement, .pipe);
        node = CodeNode.init(for_token_index, .for_block, value_node_index, items_node_index);
    } else {
        _ = try self.skipOneToken(current_statement, .r_paren);
        _ = try self.skipOneToken(current_statement, .pipe);
        const value_node_index = try self.expectIdentifierNode(current_statement);
        _ = try self.skipOneToken(current_statement, .pipe);
        node = CodeNode.init(for_token_index, .for_block, value_node_index, value_items_index);
    }
    if (first_token_index == 0) {
        return try current_statement.appendRootNode(node);
    } else {
        return try current_statement.appendNode(node);
    }
}
fn parseWhileBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const first_token_index = self.current_token_index;
    if (self.getCurrentToken(current_statement).token_type == .keyword_inline) {
        current_statement.is_inline = true;
        self.incTokenIndex();
    }
    //main_token is 'while'
    const while_token_index = try self.skipOneToken(current_statement, .keyword_while);
    _ = try self.skipOneToken(current_statement, .l_paren);
    const condition_items_index = try self.parseExpressionNode(current_statement);
    var node: CodeNode = undefined;
    if (self.getCurrentToken(current_statement).token_type == .keyword_in) {
        self.incTokenIndex();
        const items_index = try self.parseExpressionNode(current_statement);
        _ = try self.skipOneToken(current_statement, .r_paren);
        node = CodeNode.init(while_token_index, .while_block, condition_items_index, items_index);
    } else {
        _ = try self.skipOneToken(current_statement, .r_paren);
        var condition_index = null_node;
        if (self.getCurrentToken(current_statement).token_type == .pipe) {
            self.incTokenIndex();
            condition_index = try self.expectIdentifierNode(current_statement);
            _ = try self.skipOneToken(current_statement, .pipe);
        }
        node = CodeNode.init(while_token_index, .while_block, condition_index, condition_items_index);
    }
    if (first_token_index == 0) {
        return try current_statement.appendRootNode(node);
    } else {
        return try current_statement.appendNode(node);
    }
}
fn parseTestBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'test'
    const test_token_index = try self.skipOneToken(current_statement, .keyword_test);
    var right_side = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .string_literal, .identifier => {
            right_side = try self.parseExpressionValueNode(current_statement);
        },
        else => {},
    }
    const node = CodeNode.init(test_token_index, .test_block, null_node, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseDeferBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'defer'
    const defer_token_index = try self.skipOneToken(current_statement, .keyword_defer);
    var right_side = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .l_brace => {},
        else => {
            right_side = try self.parseExpressionNode(current_statement);
        },
    }
    const node = CodeNode.init(defer_token_index, ._defer, null_node, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseErrDeferBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'errdefer'
    const errdefer_token_index = try self.skipOneToken(current_statement, .keyword_errdefer);
    var right_side = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .l_brace => {},
        else => {
            right_side = try self.parseExpressionNode(current_statement);
        },
    }
    const node = CodeNode.init(errdefer_token_index, ._errdefer, null_node, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseComptimeBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is 'comptime'
    const comptime_token_index = try self.skipOneToken(current_statement, .keyword_comptime);
    var right_side = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .l_brace => {},
        else => {
            right_side = try self.parseExpressionNode(current_statement);
        },
    }
    const node = CodeNode.init(comptime_token_index, ._comptime, null_node, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseSwitchBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const first_token_index = self.current_token_index;
    //main_token is 'switch'
    const switch_token_index = try self.skipOneToken(current_statement, .keyword_switch);
    _ = try self.skipOneToken(current_statement, .l_paren);
    const condition_node_index = try self.parseExpressionNode(current_statement);
    const node = CodeNode.init(switch_token_index, .switch_block, null_node, condition_node_index);
    _ = try self.skipOneToken(current_statement, .r_paren);
    if (first_token_index == 0) {
        return try current_statement.appendRootNode(node);
    } else {
        return try current_statement.appendNode(node);
    }
}
fn parseSwitchCaseBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    //main_token is '=>'
    var case_arg_start = null_node;
    while (self.getCurrentToken(current_statement).token_type != .equal_angle_bracket_right) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        const expr_node_index = try self.parseExpressionValueNode(current_statement);
        if (case_arg_start == null_node) {
            case_arg_start = expr_node_index;
        }
        try current_statement.putArgNodeIndexMap(case_arg_start, expr_node_index);
    }
    const main_token = self.current_token_index;
    //left_side is start index in statement.arg_node_index_map key，right_side is not use
    const left_node = CodeNode.init(main_token, .case_arg, case_arg_start, null_node);
    const left_side = try current_statement.appendNode(left_node);
    self.incTokenIndex();
    var right_side = null_node;
    // std.debug.print("---------------parseSwitchCaseBlock1 wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
    switch (self.getCurrentToken(current_statement).token_type) {
        .l_brace => {
            self.incTokenIndex();
        },
        .keyword_if => {
            right_side = try self.parseIfBlock(current_statement);
        },
        .keyword_while => {
            right_side = try self.parseWhileBlock(current_statement);
        },
        .keyword_switch => {
            right_side = try self.parseSwitchBlock(current_statement);
        },
        .l_brace_r_brace => {
            right_side = try self.parseEmptyBlockNode(current_statement);
        },
        else => {
            right_side = try self.parseExpressionValueNode(current_statement);
            // std.debug.print("---------------parseSwitchCaseBlock wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
        },
    }
    //main_token is '=>'
    const node = CodeNode.init(main_token, .switch_case_block, left_side, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseDeclareParameterNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    self.current_token_index = 0;
    var node_index = try self.expectIdentifierNode(current_statement);
    //cache func param info
    var param_node = current_statement.getNode(node_index);
    if (self.getCurrentToken(current_statement).token_type == .equal) {
        //main_token is '='
        const equal_token_index = try self.skipOneToken(current_statement, .equal);
        const right_side = try self.parseExpressionNode(current_statement);
        const node = CodeNode.init(equal_token_index, .assign, node_index, right_side);
        node_index = try current_statement.appendNode(node);
        param_node = current_statement.getNode(node_index);
    }
    _ = try current_statement.removeNode(node_index);
    _ = try current_statement.appendRootNode(param_node);
    return node_index;
}
fn parseDefineVarStatement(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    var node_index = null_node;
    var left_side = null_node;
    while (self.current_token_index < current_statement.token_list.items.len - 1) {
        // std.debug.print("=============parseDefineVarStatement=={any}\n", .{self.getCurrentToken(current_statement)});
        switch (self.getCurrentToken(current_statement).token_type) {
            .keyword_pub => {
                const node = CodeNode.init(self.current_token_index, .identifier, left_side, null_node);
                left_side = try current_statement.appendNode(node);
                current_statement.is_pub = true;
                self.incTokenIndex();
            },
            .keyword_comptime => {
                const node = CodeNode.init(self.current_token_index, .identifier, left_side, null_node);
                left_side = try current_statement.appendNode(node);
                current_statement.is_comptime = true;
                self.incTokenIndex();
            },
            .keyword_const, .keyword_var => {
                const main_token_index = self.current_token_index;
                self.incTokenIndex();
                const right_side = try self.parseAssignNode(current_statement);
                //main_token is const or var
                const node = CodeNode.init(main_token_index, .define_var, left_side, right_side);
                node_index = try current_statement.appendRootNode(node);
            },
            else => {
                std.debug.print("---------------parseDefineVarStatement wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
                // for (current_statement.token_list.items) |item| {
                //     std.debug.print("=============item=={s},{any}\n", .{ item.text, item.token_type });
                // }
                return self.fail(.invalid_operator, current_statement, self.current_token_index);
            },
        }
    }
    return node_index;
}
fn parseAsmStatement(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    // `asm(rhs)`
    const main_token = try self.skipOneToken(current_statement, .keyword_asm);
    _ = try self.skipOneToken(current_statement, .l_paren);
    const right_side = try self.parseExpressionNode(current_statement);
    _ = try self.skipOneToken(current_statement, .r_paren);
    if (self.getCurrentToken(current_statement).token_type != .semicolon) {
        return self.fail(.expected_semicolon, current_statement, self.current_token_index);
    }
    const node = CodeNode.init(main_token, .asm_simple, null_node, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseZigStatement(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    // `code(rhs)`
    const main_token = try self.skipOneToken(current_statement, .keyword_code);
    _ = try self.skipOneToken(current_statement, .l_paren);
    const right_side = try self.parseExpressionNode(current_statement);
    _ = try self.skipOneToken(current_statement, .r_paren);
    if (self.getCurrentToken(current_statement).token_type != .semicolon) {
        return self.fail(.expected_semicolon, current_statement, self.current_token_index);
    }
    const node = CodeNode.init(main_token, .code_simple, null_node, right_side);
    return try current_statement.appendRootNode(node);
}
fn parseTryStatement(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    const node_index = try self.parseTryNode(current_statement);
    const node = current_statement.getNode(node_index);
    _ = try current_statement.removeNode(node_index);
    return try current_statement.appendRootNode(node);
}
fn parseCallFnStatement(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    const node_index = try self.parseExpressionNode(current_statement);
    const node = current_statement.getNode(node_index);
    _ = try current_statement.removeNode(node_index);
    return try current_statement.appendRootNode(node);
}
fn parseImportFuncNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    if (!current_statement.is_capitalization) {
        return self.fail(.expected_capitalization_for_container_name, current_statement, self.current_token_index);
    }
    const import_token_index = self.current_token_index;
    self.incTokenIndex();
    _ = try self.skipOneToken(current_statement, .l_paren);

    const import_path = self.getCurrentToken(current_statement).text;
    const func_path = import_path[1 .. import_path.len - 1];
    const func_name = try get_func_name(self.arena, func_path);
    const last_period_pos = std.mem.lastIndexOf(u8, func_name, ".");
    const func_file_name = func_name[last_period_pos.? + 1 ..];
    const first_letter = func_file_name[0];
    if (first_letter < 'A' or first_letter > 'Z') {
        return self.fail(.expected_capitalization_for_container_name, current_statement, self.current_token_index);
    }
    const depend_func = DependFunc.new(DependType.func_source, func_name, func_path);
    try self.current_func.appendDependList(depend_func);

    const right_side = try self.parseExpressionNode(current_statement);
    _ = try self.skipOneToken(current_statement, .r_paren);
    //main_token is import, `import(rhs)`
    const node = CodeNode.init(import_token_index, .import_func, null_node, right_side);
    return try current_statement.appendNode(node);
}
fn parseImportStatement(self: *Parse, current_statement: *Statement) !NodeIndex {
    self.current_token_index = 0;
    const import_token_index = self.current_token_index;
    self.incTokenIndex();
    _ = try self.skipOneToken(current_statement, .l_paren);

    var import_path_token = current_statement.getToken(self.current_token_index);
    const import_path = import_path_token.text;
    const func_path_str = import_path[1 .. import_path.len - 1];
    var all_func_path: Str = "\"";
    var func_count: usize = 0;
    var func_path_itr = std.mem.splitScalar(u8, func_path_str, ','); //mem.splitAny(u8, func_path_str, ",");
    while (func_path_itr.next()) |func_path| {
        const last_char = func_path[func_path.len - 1 ..];
        if (Util.isEql(last_char, "*")) {
            const func_dir_path = func_path[0 .. func_path.len - 1];
            var func_dir = try std.fs.cwd().openDir(func_dir_path, .{ .iterate = true });
            defer func_dir.close();
            var it = func_dir.iterate();
            while (try it.next()) |entry| {
                const ext = std.fs.path.extension(entry.name);
                if (entry.kind == .file and Util.isEql(ext, ".func")) { // std.mem.indexOf(u8, entry.name, ".func") != null) {
                    const entry_name = entry.name;
                    var last_period_pos = std.mem.lastIndexOf(u8, entry_name, ".");
                    if (last_period_pos != null and Util.isEql(entry_name[last_period_pos.?..], ".func")) {
                        const func_file_path = try Util.concat(self.arena, &.{ func_dir_path, entry.name });
                        const func_name = try get_func_name(self.arena, func_file_path);
                        last_period_pos = std.mem.lastIndexOf(u8, func_name, ".");
                        const func_file_name = func_name[last_period_pos.? + 1 ..];
                        const first_letter = func_file_name[0];
                        if (first_letter < 'A' or first_letter > 'Z') {
                            return self.fail(.expected_capitalization_for_container_name, current_statement, self.current_token_index);
                        }
                        const depend_func = DependFunc.new(DependType.func_source, func_name, func_file_path);
                        try self.current_func.appendDependList(depend_func);

                        if (func_count == 0) {
                            all_func_path = try Util.concat(self.arena, &.{ all_func_path, func_file_path });
                        } else {
                            all_func_path = try Util.concat(self.arena, &.{ all_func_path, ",", func_file_path });
                        }
                        func_count += 1;
                    }
                }
            }
        } else {
            const func_name = try get_func_name(self.arena, func_path);
            const last_period_pos = std.mem.lastIndexOf(u8, func_name, ".");
            const func_file_name = func_name[last_period_pos.? + 1 ..];
            const first_letter = func_file_name[0];
            if (first_letter < 'A' or first_letter > 'Z') {
                return self.fail(.expected_capitalization_for_container_name, current_statement, self.current_token_index);
            }
            const depend_func = DependFunc.new(DependType.func_source, func_name, func_path);
            try self.current_func.appendDependList(depend_func);

            if (func_count == 0) {
                all_func_path = try Util.concat(self.arena, &.{ all_func_path, func_path });
            } else {
                all_func_path = try Util.concat(self.arena, &.{ all_func_path, ",", func_path });
            }
            func_count += 1;
        }
    }
    all_func_path = try Util.concat(self.arena, &.{ all_func_path, "\"" });
    // std.debug.print(">>>>>>>>>>>all_func_path=={s}\n", .{all_func_path});
    import_path_token.text = all_func_path;
    try current_statement.appendTokenList(import_path_token);
    const main_token: TokenIndex = @intCast(current_statement.token_list.items.len - 1);
    //right_node's main_token is "string"
    const right_node = CodeNode.init(main_token, .string_literal, null_node, null_node);
    const right_side = try current_statement.appendNode(right_node);
    //main_token is import, `import(rhs)`
    const node = CodeNode.init(import_token_index, .import_func, null_node, right_side);
    self.incTokenIndex();
    _ = try self.skipOneToken(current_statement, .r_paren);
    return try current_statement.appendRootNode(node);
}

fn parseCatchBlock(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const current_token_type = self.getCurrentToken(current_statement).token_type;
    if (current_token_type == .l_paren or current_token_type == .pipe) {
        self.incTokenIndex();
        const left_side = try self.expectIdentifierNode(current_statement);
        //main_token is ')' or '|'
        const main_token = self.current_token_index;
        self.incTokenIndex();
        var right_side = null_node;
        switch (self.getCurrentToken(current_statement).token_type) {
            .l_brace => {},
            .keyword_return => right_side = try self.parseReturnNode(current_statement),
            .keyword_while => right_side = try self.parseWhileBlock(current_statement),
            .keyword_switch => right_side = try self.parseSwitchBlock(current_statement),
            .identifier => right_side = try self.parseExpressionNode(current_statement),
            else => {
                std.debug.print("---------------parseCatchBlock wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
                return self.fail(.invalid_token_type, current_statement, self.current_token_index);
            },
        }
        const node = CodeNode.init(main_token, .catch_body, left_side, right_side);
        return try current_statement.appendNode(node);
    } else {
        return try self.parseExpressionNode(current_statement);
    }
}
fn parseTryNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //main_token is 'try'
    const main_token = try self.skipOneToken(current_statement, .keyword_try);
    //try rhs
    var right_side = null_node;
    if (self.getCurrentToken(current_statement).token_type == .keyword_comptime) {
        const comptime_token = self.current_token_index;
        self.incTokenIndex();
        right_side = try self.parseExpressionNode(current_statement);
        const node = CodeNode.init(comptime_token, .identifier, null_node, right_side);
        right_side = try current_statement.appendNode(node);
        current_statement.is_comptime = true;
    } else {
        right_side = try self.parseExpressionNode(current_statement);
    }
    const node = CodeNode.init(main_token, ._try, null_node, right_side);
    return try current_statement.appendNode(node);
}

fn parseAssignNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const first_token_index = self.current_token_index;
    //func_name and enum_name is capitalization
    const var_name = self.getCurrentToken(current_statement).text;
    const first_letter = var_name[0];
    if (first_letter >= 'A' and first_letter <= 'Z') {
        current_statement.is_capitalization = true;
    }
    var left_side = try self.expectIdentifierNode(current_statement);
    while (self.getCurrentToken(current_statement).token_type == .comma) {
        const comma_token = self.current_token_index;
        self.incTokenIndex();
        var right_side = null_node;
        if (self.getCurrentToken(current_statement).token_type == .keyword_const or self.getCurrentToken(current_statement).token_type == .keyword_var) {
            // main_token is const or var
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right = try self.expectIdentifierNode(current_statement);
            const node = CodeNode.init(main_token, .identifier, null_node, right);
            right_side = try current_statement.appendNode(node);
        } else {
            right_side = try self.expectIdentifierNode(current_statement);
        }
        const node = CodeNode.init(comma_token, .identifier, left_side, right_side);
        left_side = try current_statement.appendNode(node);
    }
    //main_token is '=','+=','-='...
    const equal_token_index = self.current_token_index;
    self.incTokenIndex();
    const right_side = try self.parseExpressionNode(current_statement);
    const node = CodeNode.init(equal_token_index, .assign, left_side, right_side);
    //cache var name and symbol type
    const identifier_node = current_statement.getNode(left_side);
    const identifier_token_index = identifier_node.main_token;
    current_statement.name = current_statement.getToken(identifier_token_index).text;
    if (first_token_index == 0) {
        return try current_statement.appendRootNode(node);
    } else {
        return try current_statement.appendNode(node);
    }
}
fn parseExpressionNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    switch (self.getCurrentToken(current_statement).token_type) {
        .keyword_if => return try self.parseIfElseLineNode(current_statement),
        .keyword_return => return try self.parseReturnNode(current_statement),
        .keyword_import => return try self.parseImportFuncNode(current_statement),
        .keyword_enum, .keyword_union, .keyword_func, .keyword_error, .keyword_struct => return try self.parseContainerNode(current_statement),
        .l_bracket => {
            //const ty = []u8;
            if (self.getNextToken(current_statement).token_type == .r_bracket) {
                return try self.parseTypeNode(current_statement);
            } else {
                current_statement.is_array_init = true;
                return try self.parseArrayInitNode(current_statement); //array_init
            }
        },
        .asterisk, .question_mark, .keyword_fn, .keyword_align => return try self.parseTypeNode(current_statement),
        else => return try self.expectOrNode(current_statement),
    }
}
fn parseEmptyBlockNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //main_token is '{}'，left_side and right_side is not use
    const empty_node = CodeNode.init(self.current_token_index, .empty_block, null_node, null_node);
    self.incTokenIndex();
    return try current_statement.appendNode(empty_node);
}
fn parseArrayInitNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    //[[
    if (self.getNextToken(current_statement).token_type == .l_bracket) {
        //main_token is '['
        const main_token = try self.skipOneToken(current_statement, .l_bracket);
        var right_side = try self.parseExpressionNode(current_statement);
        while (self.getCurrentToken(current_statement).token_type == .r_bracket) {
            //main_token is ']'
            const node = CodeNode.init(self.current_token_index, .array_init_value, null_node, right_side);
            right_side = try current_statement.appendNode(node);
            self.incTokenIndex();
        }
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            if (self.getNextToken(current_statement).token_type == .r_bracket) {
                self.incTokenIndex();
            } else {
                //main_token is ','
                const comma_main_token = self.current_token_index;
                const left_side = right_side;
                self.incTokenIndex();
                right_side = try self.parseExpressionNode(current_statement);
                const node = CodeNode.init(comma_main_token, .array_init_comma, left_side, right_side);
                right_side = try current_statement.appendNode(node);
            }
        }
        const node = CodeNode.init(main_token, .array_init, null_node, right_side);
        return try current_statement.appendNode(node);
    } else {
        //main_token is '['
        var main_token = try self.skipOneToken(current_statement, .l_bracket);
        var right_side = try self.parseArrayInitValueNode(current_statement);
        var node = CodeNode.init(main_token, .array_init, null_node, right_side);
        right_side = try current_statement.appendNode(node);
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            if (self.getNextToken(current_statement).token_type == .r_bracket) {
                self.incTokenIndex();
            } else {
                //main_token is ','
                main_token = self.current_token_index;
                const left_side = right_side;
                self.incTokenIndex();
                right_side = try self.parseExpressionNode(current_statement);
                node = CodeNode.init(main_token, .array_init_comma, left_side, right_side);
                right_side = try current_statement.appendNode(node);
            }
        }
        return right_side;
    }
}
fn parseArrayInitValueNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var array_value_start = null_node;
    while (self.getCurrentToken(current_statement).token_type != .r_bracket) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        const array_value_node_index = try self.parseExpressionNode(current_statement);
        if (array_value_start == null_node) {
            array_value_start = array_value_node_index;
        }
        try current_statement.putArgNodeIndexMap(array_value_start, array_value_node_index);
    }
    //main_token is ']'，left_side is start index in statement.arg_node_index_map key，right_side is not use
    const value_node = CodeNode.init(self.current_token_index, .array_init_value, array_value_start, null_node);
    self.incTokenIndex();
    return try current_statement.appendNode(value_node);
}
fn expectOrNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectAndNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .keyword_or => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectAndNode(current_statement);
            //main_token is 'or'
            const node = CodeNode.init(main_token, .bool_or, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectAndNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectCompareNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .keyword_or => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectAndNode(current_statement);
            //main_token is 'or'
            const node = CodeNode.init(main_token, .bool_or, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .keyword_and => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectCompareNode(current_statement);
            //main_token is 'and'
            const node = CodeNode.init(main_token, .bool_and, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectCompareNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectBitOrNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .keyword_and => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectCompareNode(current_statement);
            //main_token is 'and'
            const node = CodeNode.init(main_token, .bool_and, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .equal_equal, .bang_equal, .angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_right, .angle_bracket_right_equal => {
            const main_token = self.current_token_index;
            const node_type = compareTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectBitOrNode(current_statement);
            //main_token is '=='、'!='、'<'、'<='、'>'、'>='
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectBitOrNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectBitXorNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .equal_equal, .bang_equal, .angle_bracket_left, .angle_bracket_left_equal, .angle_bracket_right, .angle_bracket_right_equal => {
            const main_token = self.current_token_index;
            const node_type = compareTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectBitOrNode(current_statement);
            //main_token is '=='、'!='、'<'、'<='、'>'、'>='
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .pipe => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectBitXorNode(current_statement);
            //main_token is '|'
            const node = CodeNode.init(main_token, .bit_or, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectBitXorNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectBitAndNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .pipe => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectBitXorNode(current_statement);
            //main_token is '|'
            const node = CodeNode.init(main_token, .bit_or, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .caret => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectBitAndNode(current_statement);
            //main_token is '^'
            const node = CodeNode.init(main_token, .bit_xor, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectBitAndNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectBitShiftNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .caret => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectBitAndNode(current_statement);
            //main_token is '^'
            const node = CodeNode.init(main_token, .bit_xor, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .ampersand => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectBitShiftNode(current_statement);
            //main_token is '&'
            const node = CodeNode.init(main_token, .bit_and, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectBitShiftNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectAddSubtractNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .ampersand => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const right_side = try self.expectBitShiftNode(current_statement);
            //main_token is '&'
            const node = CodeNode.init(main_token, .bit_and, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .angle_bracket_angle_bracket_left, .angle_bracket_angle_bracket_right => {
            const main_token = self.current_token_index;
            const node_type = bitShiftTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectAddSubtractNode(current_statement);
            //main_token is '<<'、'>>
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectAddSubtractNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectMulDivModNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .angle_bracket_angle_bracket_left, .angle_bracket_angle_bracket_right => {
            const main_token = self.current_token_index;
            const node_type = bitShiftTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectAddSubtractNode(current_statement);
            //main_token is '<<'、'>>
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .plus, .minus, .plus_plus => {
            const main_token = self.current_token_index;
            const node_type = addSubtractTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectMulDivModNode(current_statement);
            //main_token is '+'、'++'、'-'
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectMulDivModNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    const left_side = try self.expectUnaryNode(current_statement);
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .plus, .minus, .plus_plus => {
            const main_token = self.current_token_index;
            const node_type = addSubtractTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectMulDivModNode(current_statement);
            //main_token is '+'、'++'、'-'
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        .asterisk, .slash, .percent, .asterisk_asterisk, .pipe_pipe => {
            const main_token = self.current_token_index;
            const node_type = mulDivModTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.expectUnaryNode(current_statement);
            //main_token is '*'、'/'、'%'
            const node = CodeNode.init(main_token, node_type, left_side, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            node_index = left_side;
        },
    }
    return node_index;
}
fn expectUnaryNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .minus, .bang, .tilde, .ampersand => {
            const main_token = self.current_token_index;
            const node_type = unaryTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
            self.incTokenIndex();
            const right_side = try self.parseExpressionNode(current_statement);
            //main_token is '-'、'!'、'~'、'&'
            const node = CodeNode.init(main_token, node_type, null_node, right_side);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            const left_side = try self.parseExpressionValueNode(current_statement);
            switch (self.getCurrentToken(current_statement).token_type) {
                .asterisk, .slash, .percent, .asterisk_asterisk, .pipe_pipe => {
                    const main_token = self.current_token_index;
                    const node_type = mulDivModTable[@as(usize, @intCast(@intFromEnum(self.getCurrentToken(current_statement).token_type)))];
                    self.incTokenIndex();
                    const right_side = try self.expectUnaryNode(current_statement);
                    //main_token is '*'、'/'、'%'
                    const node = CodeNode.init(main_token, node_type, left_side, right_side);
                    node_index = try current_statement.appendNode(node);
                },
                else => {
                    node_index = left_side;
                },
            }
        },
    }
    return node_index;
}
fn parseExpressionValueNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .identifier => {
            node_index = try self.expectIdentifierNode(current_statement);
        },
        .keyword_try => {
            node_index = try self.parseTryNode(current_statement);
        },
        .keyword_else => { //only for switch case
            const main_token = self.current_token_index;
            const node = CodeNode.init(main_token, .identifier, null_node, null_node);
            node_index = try current_statement.appendNode(node);
            self.incTokenIndex();
        },
        .period => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const node = CodeNode.init(main_token, .field_access, null_node, try self.expectIdentifierNode(current_statement));
            node_index = try current_statement.appendNode(node);
        },
        .period_l_brace => { // '.{'
            const main_token = self.current_token_index;
            self.incTokenIndex();
            var arg_node_start = null_node;
            while (self.getCurrentToken(current_statement).token_type != .r_brace) {
                if (self.getCurrentToken(current_statement).token_type == .comma) {
                    self.incTokenIndex();
                    continue;
                }
                if (self.getCurrentToken(current_statement).token_type == .period) {
                    self.incTokenIndex();
                }
                const arg_node_index = try self.parseOneFuncInitArgNode(current_statement);
                if (arg_node_start == null_node) {
                    arg_node_start = arg_node_index;
                }
                try current_statement.putArgNodeIndexMap(arg_node_start, arg_node_index);
            }
            _ = try self.skipOneToken(current_statement, .r_brace);
            //right_side is start index in statement.arg_node_index_map key，left_side is not use
            const node = CodeNode.init(main_token, .func_init_dot, null_node, arg_node_start);
            node_index = try current_statement.appendNode(node);
        },
        .number_literal, .char_literal => {
            const node_type = if (self.getCurrentToken(current_statement).token_type == .number_literal) NodeType.number_literal else NodeType.char_literal;
            const number_token = self.current_token_index;
            self.incTokenIndex();
            //main_token is 123 or 'c'
            const node = CodeNode.init(number_token, node_type, null_node, null_node);
            node_index = try current_statement.appendNode(node);
            if (self.getCurrentToken(current_statement).token_type == .ellipsis3) {
                const main_token = self.current_token_index;
                self.incTokenIndex();
                const right_side = try self.parseExpressionValueNode(current_statement);
                //`lhs...rhs`. main_token is '...'
                const switch_range_node = CodeNode.init(main_token, .switch_range, node_index, right_side);
                node_index = try current_statement.appendNode(switch_range_node);
            }
        },
        .string_literal => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            //main_token is "string"
            const node = CodeNode.init(main_token, .string_literal, null_node, null_node);
            node_index = try current_statement.appendNode(node);
        },
        .multiline_string_literal => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            //main_token is "'''abc'''"
            const node = CodeNode.init(main_token, .multiline_string_literal, null_node, null_node);
            node_index = try current_statement.appendNode(node);
        },
        .l_paren => {
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const left_side = try self.parseExpressionNode(current_statement);
            const token_index = try self.skipOneToken(current_statement, .r_paren);
            const right_node = CodeNode.init(token_index, .grouped_expression, null_node, null_node);
            const right_side = try current_statement.appendNode(right_node);
            //main_token is '(', left_side is expression, right_side is ')'
            const node = CodeNode.init(main_token, .grouped_expression, left_side, right_side);
            node_index = try current_statement.appendNode(node);
            switch (self.getCurrentToken(current_statement).token_type) {
                .period, .l_bracket => {
                    node_index = try self.parsePeriodRightNode(current_statement, node_index);
                },
                else => {},
            }
        },
        .l_brace_r_brace => {
            node_index = try self.parseEmptyBlockNode(current_statement);
        },
        .asterisk => { // [*]
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const node = CodeNode.init(main_token, .pointer_type, null_node, null_node);
            node_index = try current_statement.appendNode(node);
        },
        else => {
            std.debug.print("---------------parseExpressionValueNode wrong func: {s}, token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
            self.incTokenIndex();
            return self.fail(.expected_identifier_value, current_statement, self.current_token_index);
        },
    }
    return node_index;
}
fn expectIdentifierNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    if (self.getCurrentToken(current_statement).token_type != .identifier) {
        return self.fail(.expected_identifier, current_statement, self.current_token_index);
    }
    const identifier_token_index = self.current_token_index;
    const identifier_name = current_statement.getToken(identifier_token_index).text;
    self.incTokenIndex();
    var identifier_node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .colon => {
            self.incTokenIndex();
            const current_token_type = self.getCurrentToken(current_statement).token_type;
            var right_side = null_node;
            if (current_token_type == .bang) {
                //right_side is !rhs
                right_side = try self.parseTypeNode(current_statement);
            } else if (current_token_type == .question_mark) {
                //right_side is ?rhs
                right_side = try self.parseTypeNode(current_statement);
            } else if (current_token_type == .asterisk) {
                //right_side is *rhs
                right_side = try self.parseTypeNode(current_statement);
            } else if (current_token_type == .l_bracket) {
                right_side = try self.parseTypeNode(current_statement);
            } else if (current_token_type == .keyword_fn) {
                right_side = try self.parseFnTypeNode(current_statement);
            } else {
                //rhs is identifier
                right_side = try self.expectIdentifierNode(current_statement);
                if (self.getCurrentToken(current_statement).token_type == .bang) {
                    // `lhs!rhs`. main_token is the `!`.
                    right_side = try self.parseErrorUnionTypeNode(current_statement, right_side);
                }
            }
            const node = CodeNode.init(identifier_token_index, .var_decl, null_node, right_side);
            identifier_node_index = try current_statement.appendNode(node);
        },
        .l_bracket => { //array_access
            const left_node = CodeNode.init(identifier_token_index, .identifier, null_node, null_node);
            const left_side = try current_statement.appendNode(left_node);
            // `a[1]`. main_token is the '['. lhs is identifier, rhs is the ']'.
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const array_access_node_index = try self.parseArrayAccessNode(current_statement);
            const node = CodeNode.init(main_token, .array_access, left_side, array_access_node_index);
            identifier_node_index = try current_statement.appendNode(node);
        },
        .period_asterisk, .period_question, .period => {
            const left_node = CodeNode.init(identifier_token_index, .identifier, null_node, null_node);
            const left_side = try current_statement.appendNode(left_node);
            identifier_node_index = try self.parsePeriodRightNode(current_statement, left_side);
        },
        else => {
            switch (self.getCurrentToken(current_statement).token_type) {
                .l_paren => { // call function
                    const first_letter = identifier_name[0];
                    if (first_letter >= 'A' and first_letter <= 'Z') {
                        return self.fail(.expected_no_capitalization_for_function_name, current_statement, self.current_token_index);
                    }
                    const node = CodeNode.init(identifier_token_index, .identifier, null_node, null_node);
                    identifier_node_index = try current_statement.appendNode(node);
                    identifier_node_index = try self.parseCallFnNode(current_statement, identifier_node_index);
                },
                else => {
                    if (self.getCurrentToken(current_statement).token_type == .l_brace and current_statement.is_container) {
                        // func_init, right_side is func_arg list node
                        const right_side = try self.parseFuncInitArgListNode(current_statement);
                        // main_token is func_name, `func_name{rhs}`, lhs is not use
                        const func_init_node = CodeNode.init(identifier_token_index, .func_init, null_node, right_side);
                        identifier_node_index = try current_statement.appendNode(func_init_node);
                    } else {
                        const node = CodeNode.init(identifier_token_index, .identifier, null_node, null_node);
                        identifier_node_index = try current_statement.appendNode(node);
                    }
                },
            }
        },
    }
    return identifier_node_index;
}
fn parseCallFnNode(self: *Parse, current_statement: *Statement, left_side: NodeIndex) Error!NodeIndex {
    //func.a() or a()
    //main_token is '('
    const main_token = try self.skipOneToken(current_statement, .l_paren);
    var arg_node_start = null_node;
    while (self.getCurrentToken(current_statement).token_type != .r_paren) {
        if (self.getCurrentToken(current_statement).token_type == .comma) {
            self.incTokenIndex();
            continue;
        }
        const arg_node_index = try self.parseExpressionNode(current_statement);
        if (arg_node_start == null_node) {
            arg_node_start = arg_node_index;
        }
        try current_statement.putArgNodeIndexMap(arg_node_start, arg_node_index);
    }
    //main_token is ')'，left_side is start index in statement.arg_node_index_map key，right_side is not use
    const right_side_node = CodeNode.init(self.current_token_index, .fn_arg, arg_node_start, null_node);
    const right_side = try current_statement.appendNode(right_side_node);
    self.incTokenIndex();
    const node = CodeNode.init(main_token, .call_fn, left_side, right_side);
    var node_index = try current_statement.appendNode(node);
    if (self.getCurrentToken(current_statement).token_type == .keyword_catch) {
        //main_token is 'catch'
        const catch_main_token = self.current_token_index;
        self.incTokenIndex();
        var catch_right_side = null_node;
        if (self.getCurrentToken(current_statement).token_type != .l_brace) {
            catch_right_side = try self.parseCatchBlock(current_statement);
        }
        const catch_node = CodeNode.init(catch_main_token, ._catch, node_index, catch_right_side);
        node_index = try current_statement.appendNode(catch_node);
    } else if (self.getCurrentToken(current_statement).token_type != .semicolon) {
        node_index = try self.parsePeriodRightNode(current_statement, node_index);
    }
    return node_index;
}
fn parseArrayAccessNode(self: *Parse, current_statement: *Statement) Error!NodeIndex {
    var left_side = try self.parseExpressionNode(current_statement);
    var r_bracket_token_index: TokenIndex = 0;
    if (self.getCurrentToken(current_statement).token_type == .ellipsis2) {
        // `a[1..3]` or a[1..]. main_token is the .., lhs is expression node, rhs can be not use.
        const ellipsis2_token = self.current_token_index;
        self.incTokenIndex();
        const right_side = if (self.getCurrentToken(current_statement).token_type != .r_bracket) try self.parseExpressionNode(current_statement) else null_node;
        const node = CodeNode.init(ellipsis2_token, .slice, left_side, right_side);
        left_side = try current_statement.appendNode(node);
        r_bracket_token_index = try self.skipOneToken(current_statement, .r_bracket);
    } else {
        r_bracket_token_index = try self.skipOneToken(current_statement, .r_bracket);
    }
    var right_node_index = null_node;
    if (self.getCurrentToken(current_statement).token_type != .semicolon) {
        right_node_index = try self.parsePeriodRightNode(current_statement, right_node_index);
    }
    const node = CodeNode.init(r_bracket_token_index, .array_access, left_side, right_node_index);
    return try current_statement.appendNode(node);
}
fn parsePeriodRightNode(self: *Parse, current_statement: *Statement, node_index: NodeIndex) Error!NodeIndex {
    var right_node_index = null_node;
    switch (self.getCurrentToken(current_statement).token_type) {
        .l_bracket => {
            //main_token is '['
            const main_token = self.current_token_index;
            self.incTokenIndex();
            right_node_index = try self.parseArrayAccessNode(current_statement);
            const node = CodeNode.init(main_token, .array_access, node_index, right_node_index);
            right_node_index = try current_statement.appendNode(node);
        },
        .identifier => {
            right_node_index = try self.expectIdentifierNode(current_statement);
        },
        .period_asterisk => {
            // `a[1].*`. main_token is the .*, lhs and rhs is not use.
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const node = CodeNode.init(main_token, .deref, node_index, null_node);
            right_node_index = try current_statement.appendNode(node);
            switch (self.getCurrentToken(current_statement).token_type) {
                .period_asterisk, .period_question, .period => {
                    right_node_index = try self.parsePeriodRightNode(current_statement, right_node_index);
                },
                else => {},
            }
        },
        .period_question => {
            // `a[1].?`. main_token is the .?, rhs is not use.
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const node = CodeNode.init(main_token, .unwrap_optional, node_index, null_node);
            right_node_index = try current_statement.appendNode(node);
            switch (self.getCurrentToken(current_statement).token_type) {
                .period_asterisk, .period_question, .period => {
                    right_node_index = try self.parsePeriodRightNode(current_statement, right_node_index);
                },
                else => {},
            }
        },
        .period => {
            // `a[1].a`. main_token is the dot. lhs is not use, and rhs is the identifier node index.
            const main_token = self.current_token_index;
            self.incTokenIndex();
            const node = CodeNode.init(main_token, .field_access, node_index, try self.expectIdentifierNode(current_statement));
            right_node_index = try current_statement.appendNode(node);
            switch (self.getCurrentToken(current_statement).token_type) {
                .period_asterisk, .period_question, .period => {
                    right_node_index = try self.parsePeriodRightNode(current_statement, right_node_index);
                },
                else => {},
            }
        },
        else => {
            right_node_index = node_index;
        },
    }
    return right_node_index;
}

fn skipOneToken(self: *Parse, current_statement: *Statement, token_type: TokenType) Error!TokenIndex {
    const token_index = self.current_token_index;
    if (self.getCurrentToken(current_statement).token_type != token_type) {
        std.debug.print("---------------skipOneToken wrong func: {s}, token_type: {any}, skip_token_type: {any}, line_no={d}, column_no={d}\n", .{ self.current_func.func_path, self.getCurrentToken(current_statement).token_type, token_type, self.getCurrentToken(current_statement).line_no, self.getCurrentToken(current_statement).column_no });
        return self.fail(.invalid_token_type, current_statement, self.current_token_index);
    }
    self.incTokenIndex();
    return token_index;
}

fn warn(self: *Parse, error_tag: FuncError.Tag) error{OutOfMemory}!void {
    try self.warnMsg(.{ .tag = error_tag, .token = self.current_token_index });
}

fn warnMsg(self: *Parse, msg: FuncError) error{OutOfMemory}!void {
    try self.errors.append(self.arena, msg);
}

fn fail(self: *Parse, tag: FuncError.Tag, statement: *Statement, token_index: TokenIndex) error{ ParseError, OutOfMemory } {
    const error_text = FuncErrorTable[@as(usize, @intCast(@intFromEnum(tag)))];
    const func_name = try Util.copy(self.arena, self.current_func.name);
    std.mem.replaceScalar(u8, func_name, '_', '/');
    var column_no: usize = undefined;
    var line_no: usize = undefined;
    if (statement.token_list.items.len > 0) {
        var index = token_index;
        if (index >= statement.token_list.items.len) {
            index = @as(u32, @intCast(statement.token_list.items.len)) - 1;
        }
        column_no = statement.getToken(index).column_no;
        line_no = statement.getToken(index).line_no;
    } else {
        column_no = 1;
        line_no = statement.line_no;
    }
    return self.failMsg(.{ .tag = tag, .error_text = error_text, .statement = statement.*, .token_index = token_index, .func_name = func_name, .line_no = line_no, .column_no = column_no });
}

fn failMsg(self: *Parse, msg: FuncError) error{ ParseError, OutOfMemory } {
    try self.warnMsg(msg);
    return error.ParseError;
}

fn printFuncStatementTokenList(current_statement: *Statement) void {
    for (current_statement.token_list.items) |token| {
        std.debug.print("token.text = '{s}', token.line_no = '{d}', token_type={any}, code_type={any}\n", .{ token.text, token.line_no, token.token_type, current_statement.code_type });
    }
}

const compareTable = std.enums.directEnumArrayDefault(TokenType, NodeType, .root, 0, .{
    .equal_equal = .equal_equal,
    .bang_equal = .bang_equal,
    .angle_bracket_left = .less_than,
    .angle_bracket_left_equal = .less_or_equal,
    .angle_bracket_right = .greater_than,
    .angle_bracket_right_equal = .greater_or_equal,
});
const bitShiftTable = std.enums.directEnumArrayDefault(TokenType, NodeType, .root, 0, .{
    .angle_bracket_angle_bracket_left = .shl,
    .angle_bracket_angle_bracket_right = .shr,
});
const addSubtractTable = std.enums.directEnumArrayDefault(TokenType, NodeType, .root, 0, .{
    .plus = .add,
    .plus_plus = .array_cat,
    .minus = .sub,
});
const mulDivModTable = std.enums.directEnumArrayDefault(TokenType, NodeType, .root, 0, .{
    .asterisk = .mul,
    .slash = .div,
    .percent = .mod,
    .asterisk_asterisk = .array_mult,
    .pipe_pipe = .merge_error_sets,
});
const unaryTable = std.enums.directEnumArrayDefault(TokenType, NodeType, .root, 0, .{
    .bang = .bool_not,
    .minus = .negation,
    .tilde = .bit_not,
    .ampersand = .address_of,
});
