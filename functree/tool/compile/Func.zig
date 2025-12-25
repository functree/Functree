const std = @import("std");
const builtin = @import("builtin");
const unicode = @import("std").unicode;
const Utf8Iterator = @import("std").unicode.Utf8Iterator;
const StringHashMap = std.StringHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Util = @import("Util.zig");
const Str = []const u8;
pub const TokenIndex = u32;
pub const NodeIndex = u32;

pub const Func = @This();

/// Arena-allocated memory, mostly used during initialization. However, it can
/// be used for other things requiring the same lifetime as the Func.
arena: Allocator,
name: Str,
func_path: Str,

statement_list: ArrayList(Statement),
depend_func_list: ArrayList(DependFunc),

pub fn init(arena: Allocator, func_name: Str, func_path: Str) Func {
    const self = Func{
        .arena = arena,
        .name = func_name,
        .func_path = func_path,
        .statement_list = .empty,
        .depend_func_list = .empty,
    };
    return self;
}

pub fn appendStatementList(self: *Func, statement: Statement) !void {
    try self.statement_list.append(self.arena, statement);
}
pub fn appendDependList(self: *Func, depend_func: DependFunc) !void {
    try self.depend_func_list.append(self.arena, depend_func);
}

pub const DependFunc = struct {
    depend_type: DependType,
    func_name: Str,
    func_path: Str,
    pub fn new(depend_type: DependType, func_name: Str, func_path: Str) DependFunc {
        const self = DependFunc{
            .depend_type = depend_type,
            .func_name = func_name,
            .func_path = func_path,
        };
        return self;
    }
    pub fn deinit(self: DependFunc) void {
        _ = self;
    }
};
pub const DependType = enum {
    func_source,
    elf_bin,
    coff_bin,
};
pub const StatementState = enum {
    period_init_start,
    period_init_end,
};

pub const Statement = struct {
    /// Arena-allocated memory, mostly used during initialization. However, it can
    /// be used for other things requiring the same lifetime as the Func.
    arena: Allocator,
    line_no: usize,
    code_type: CodeType,
    token_list: ArrayList(Token),
    node_map: std.AutoHashMap(NodeIndex, CodeNode),
    arg_node_index_map: std.AutoHashMap(NodeIndex, ArrayList(NodeIndex)),
    parent: ?*Statement,
    child_list: ArrayList(Statement),
    is_pub: bool,
    is_comptime: bool,
    is_inline: bool,
    ///func_name和enum_name等的首字母大写
    is_capitalization: bool = false,
    is_array_init: bool = false,
    is_container: bool = false,
    is_fn: bool = false,
    have_const_var: bool = false,
    name: Str,
    scope: Str,
    state: StatementState,

    pub fn init(arena: Allocator, line_no: usize, scope: Str, parent: ?*Statement) Statement {
        const self = Statement{
            .arena = arena,
            .line_no = line_no,
            .code_type = CodeType.unkown,
            .token_list = .empty,
            .node_map = std.AutoHashMap(NodeIndex, CodeNode).init(arena),
            .arg_node_index_map = std.AutoHashMap(NodeIndex, ArrayList(NodeIndex)).init(arena),
            .parent = parent,
            .child_list = .empty,
            .is_pub = false,
            .is_comptime = false,
            .is_inline = false,
            .name = "",
            .scope = scope,
            .state = .period_init_end,
        };
        return self;
    }

    pub fn appendTokenList(self: *Statement, token: Token) !void {
        try self.token_list.append(self.arena, token);
    }
    pub fn getToken(self: Statement, token_index: TokenIndex) Token {
        return self.token_list.items[token_index];
    }

    pub fn appendRootNode(self: *Statement, node: CodeNode) !NodeIndex {
        const root_node_index = 0;
        try self.node_map.put(root_node_index, node);
        return root_node_index;
    }
    pub fn appendNode(self: *Statement, node: CodeNode) !NodeIndex {
        const node_index = @as(NodeIndex, @intCast(self.node_map.count())) + 1;
        try self.node_map.put(node_index, node);
        return node_index;
    }
    pub fn removeNode(self: *Statement, node_index: NodeIndex) !bool {
        return self.node_map.remove(node_index);
    }
    pub fn getNode(self: Statement, node_index: NodeIndex) CodeNode {
        const node = self.node_map.get(node_index);
        return node.?;
    }
    pub fn setNode(self: *Statement, node_index: NodeIndex, node: CodeNode) !NodeIndex {
        try self.node_map.put(node_index, node);
        return node_index;
    }
    pub fn putArgNodeIndexMap(self: *Statement, param_arg_index: NodeIndex, node_index: NodeIndex) !void {
        const node_index_list = self.arg_node_index_map.getPtr(param_arg_index);
        if (node_index_list == null) {
            var list: ArrayList(NodeIndex) = .empty;
            try list.append(self.arena, node_index);
            try self.arg_node_index_map.put(param_arg_index, list);
        } else {
            try node_index_list.?.*.append(self.arena, node_index);
        }
    }

    pub fn getText(self: Statement) !Str {
        var text: Str = "";
        var previous_token_text: Str = "";
        for (self.token_list.items) |token| {
            if (Util.isEql(text, "")) {
                text = try Util.concat(self.arena, &.{ text, token.text });
            } else {
                switch (token.text[0]) {
                    '.', ',', ';', ':', '(', ')', '[', ']' => {
                        if (Util.isEql(previous_token_text, ":")) {
                            text = try Util.concat(self.arena, &.{ text, " ", token.text });
                        } else {
                            text = try Util.concat(self.arena, &.{ text, token.text });
                        }
                    },
                    else => {
                        if (Util.isEql(previous_token_text, ".") or Util.isEql(previous_token_text, "(") or Util.isEql(previous_token_text, "[") or Util.isEql(previous_token_text, "]")) {
                            text = try Util.concat(self.arena, &.{ text, token.text });
                        } else {
                            text = try Util.concat(self.arena, &.{ text, " ", token.text });
                        }
                    },
                }
            }
            previous_token_text = token.text;
        }
        return text;
    }

    pub fn appendChildStatementList(self: *Statement, statement: Statement) !void {
        try self.child_list.append(self.arena, statement);
    }
    pub fn getChildStatementList(self: *Statement) ArrayList(Statement) {
        return self.child_list;
    }
};

pub const Token = struct {
    token_type: TokenType,
    text: Str,
    line_no: usize,
    column_no: usize,

    pub fn init(token_type: TokenType, line_no: usize, column_no: usize) Token {
        const self = Token{
            .token_type = token_type,
            .text = "",
            .line_no = line_no,
            .column_no = column_no,
        };
        return self;
    }
    pub fn deinit(self: Token) void {
        _ = self;
    }
};

pub const CodeNode = struct {
    node_type: NodeType,
    main_token: TokenIndex,
    left_side: NodeIndex,
    right_side: NodeIndex,

    pub fn init(main_token: TokenIndex, node_type: NodeType, left_side: NodeIndex, right_side: NodeIndex) CodeNode {
        const self = CodeNode{
            .node_type = node_type,
            .main_token = main_token,
            .left_side = left_side,
            .right_side = right_side,
        };
        return self;
    }
};

pub const NodeType = enum {
    root,
    /// import("functree/system/Memory.func")
    import_func,
    /// `pub var rhs`, main_token is var or const
    define_var,
    /// `a: rhs`. rhs may be unused.
    var_decl,
    /// `a(param_node_start, param_node_end)`
    fn_param,
    /// `lhs = rhs`. main_token is `=`.
    assign,
    /// `lhs || rhs`. main_token is `||`.
    merge_error_sets,
    /// `lhs ** rhs`. main_token is the `**`.
    array_mult,
    /// `[lhs]rhs`.
    array_type,
    /// `lhs[rhs]`.
    array_access,
    /// `[rhs]`, main_token is the `[`, rhs is '.array_init_value' node
    array_init,
    /// `[lhs,rhs]`, main_token is the `,`, lhs and rhs is '.array_init' or 'array_init_comma' node
    array_init_comma,
    ///`[value_node_index_start, value_node_index_end]`, main_token is the `]`, lhs is value_node_index_start, rhs is value_node_index_end
    array_init_value,
    /// `*align(1) fn () void`.
    type_expr,
    align_type,
    callconv_type,
    /// `lhs[b..c]`
    /// main_token is the '..'.
    slice,
    /// `?lhs`. rhs unused. main_token is the `?`.
    optional_type,
    /// lhs is index into ptr_type. rhs is the element type expression.
    /// main_token is the asterisk
    /// main_token might be a ** token, which is shared with a parent/child
    /// pointer type and may require special handling.
    pointer_type,
    /// `lhs.*`. rhs is unused.
    deref,
    /// `lhs.?`. main_token is the dot. rhs is the `?` token index.
    unwrap_optional,
    /// `error.a`. lhs is token index of `.`. rhs is token index of `a`.
    error_value,
    /// `lhs!rhs`. main_token is the `!`.
    error_union,
    /// `lhs + rhs`. main_token is the `+`.
    add,
    /// `lhs ++ rhs`. main_token is the `++`.
    array_cat,
    /// `lhs - rhs`. main_token is the `-`.
    sub,
    /// `lhs * rhs`. main_token is the `*`.
    mul,
    /// `lhs / rhs`. main_token is the `/`.
    div,
    /// `lhs % rhs`. main_token is the `%`.
    mod,
    /// `-lhs`. rhs unused. main_token is op.
    negation,
    /// `lhs << rhs`. main_token is the `<<`.
    shl,
    /// `lhs >> rhs`. main_token is the `>>`.
    shr,
    /// `lhs & rhs`. main_token is the `&`.
    bit_and,
    /// `lhs ^ rhs`. main_token is the `^`.
    bit_xor,
    /// `lhs | rhs`. main_token is the `|`.
    bit_or,
    /// `~lhs`. rhs unused. main_token is op.
    bit_not,
    /// `lhs and rhs`. main_token is the `and`.
    bool_and,
    /// `lhs or rhs`. main_token is the `or`.
    bool_or,
    /// `!lhs`. rhs unused. main_token is op.
    bool_not,
    /// `&lhs`. rhs unused. main_token is op.
    address_of,
    /// lhs catch rhs
    /// lhs catch |err| rhs
    /// main_token is the `catch` keyword.
    /// payload is determined by looking at the next token after the `catch` keyword.
    _catch,
    /// `op rhs`. lhs unused. main_token is op.
    _try,
    call_fn,
    fn_type,
    func_init,
    func_init_arg,
    /// `.{.a = b, .c = d}`.
    func_init_dot,
    /// `(arg_node_index_start, arg_node_index_end)`, main_token is the `)`, lhs is arg_node_index_start, rhs is arg_node_index_end
    fn_arg,
    /// `comptime rhs`. lhs unused.
    _comptime,
    case_arg,
    catch_body,
    /// `lhs == rhs`. main_token is op.
    equal_equal,
    /// `lhs != rhs`. main_token is op.
    bang_equal,
    /// `lhs < rhs`. main_token is op.
    less_than,
    /// `lhs > rhs`. main_token is op.
    greater_than,
    /// `lhs <= rhs`. main_token is op.
    less_or_equal,
    /// `lhs >= rhs`. main_token is op.
    greater_or_equal,
    /// Both lhs and rhs unused.
    /// Most identifiers will not have explicit AST nodes, however for expressions
    /// which could be one of many different kinds of AST nodes, there will be an
    /// identifier AST node for it.
    identifier,
    /// Both lhs and rhs unused.
    char_literal,
    /// Both lhs and rhs unused.
    number_literal,
    /// `lhs.a`. main_token is the dot. rhs is the identifier token index.
    field_access,
    /// lhs is the dot token index, rhs unused, main_token is the identifier.
    // enum_literal,
    /// main_token is the string literal token
    /// Both lhs and rhs unused.
    string_literal,
    /// main_token is the first token index (redundant with lhs)
    /// lhs is the first token index; rhs is the last token index.
    /// Could be a series of multiline_string_literal tokens, or a single
    /// string_literal token.
    multiline_string_literal,
    /// `(lhs)`. main_token is the `(`; rhs is the token index of the `)`.
    grouped_expression,
    /// `func {}`, `error {}`, `enum {}`.
    /// main_token is `func`, `error`, `enum` keyword.
    container_decl,
    container_field, // `enum(field_node_start, field_node_end)`

    /// `continue`. lhs is token index of label if any. rhs is unused.
    _continue,
    /// `break :lhs rhs`
    /// both lhs and rhs may be omitted.
    _break,
    /// `return lhs`. lhs can be omitted. rhs is unused.
    _return,
    define_fn,
    fn_proto,
    _block,
    empty_block,
    /// `if lhs else rhs`.
    if_else_line,
    if_block,
    else_block,
    for_block,
    while_block,
    switch_block,
    switch_case_block,
    /// `lhs...rhs`.
    switch_range,
    /// `asm(rhs)`
    asm_simple,
    /// `code(rhs)`
    code_simple,
    test_block,

    /// lhs is unused.
    /// rhs is the deferred expression or block.
    _defer,
    _errdefer,
};

pub const CodeType = enum {
    /// `var a = rhs;`
    /// `var a: lhs = rhs;`
    define_var,
    /// `a: lhs,` or `a: lhs = rhs,`
    declare_param,
    assign,
    /// `continue`. lhs is token index of label if any. rhs is unused.
    _continue,
    /// `break :lhs rhs`
    /// both lhs and rhs may be omitted.
    _break,
    /// `return lhs`. lhs can be omitted. rhs is unused.
    _return,
    call_fn,
    /// `asm(rhs)`
    _asm,
    /// `code(rhs)`
    code,
    /// `try rhs`. lhs unused. main_token is 'try'.
    _try,
    /// `import(rhs)`. lhs unused. main_token is 'import'.
    import,

    _block,
    define_fn,
    if_block,
    else_block,
    for_block,
    while_block,
    switch_block,
    switch_case_block,
    /// lhs is test name token (must be string literal or identifier), if any.
    /// rhs is the body node.
    test_block,

    _defer,
    _errdefer,
    _comptime,

    unkown,
    invalid,
};

pub const KeywordMap = std.StaticStringMap(TokenType).initComptime(.{
    .{ "align", .keyword_align },
    .{ "and", .keyword_and },
    .{ "asm", .keyword_asm },
    .{ "async", .keyword_async },
    .{ "await", .keyword_await },
    .{ "break", .keyword_break },
    .{ "callconv", .keyword_callconv },
    .{ "catch", .keyword_catch },
    .{ "comptime", .keyword_comptime },
    .{ "const", .keyword_const },
    .{ "continue", .keyword_continue },
    .{ "defer", .keyword_defer },
    .{ "else", .keyword_else },
    .{ "enum", .keyword_enum },
    .{ "errdefer", .keyword_errdefer },
    .{ "error", .keyword_error },
    // .{ "false", .keyword_false },
    .{ "fn", .keyword_fn },
    .{ "for", .keyword_for },
    .{ "func", .keyword_func },
    .{ "if", .keyword_if },
    .{ "import", .keyword_import },
    .{ "in", .keyword_in },
    .{ "inline", .keyword_inline },
    // .{ "null", .keyword_null },
    .{ "or", .keyword_or },
    .{ "pub", .keyword_pub },
    .{ "resume", .keyword_resume },
    .{ "return", .keyword_return },
    .{ "struct", .keyword_struct },
    .{ "switch", .keyword_switch },
    .{ "test", .keyword_test },
    .{ "try", .keyword_try },
    // .{ "true", .keyword_true },
    // .{ "undefined", .keyword_undefined },
    // .{ "unreachable", .keyword_unreachable },
    .{ "union", .keyword_union },
    .{ "var", .keyword_var },
    //.{ "void", .keyword_void },
    .{ "while", .keyword_while },
    .{ "code", .keyword_code },
});
pub const OperatorMap = std.StaticStringMap(TokenType).initComptime(.{
    .{ "(", .l_paren },
    .{ ")", .r_paren },
    .{ "=", .equal },
    .{ "+", .plus },
    .{ "++", .plus_plus },
    .{ "-", .minus },
    .{ "*", .asterisk },
    .{ "/", .slash },
    .{ "%", .percent },
    .{ "!", .bang },
    .{ "|", .pipe },
    .{ "==", .equal_equal },
    .{ "!=", .bang_equal },
    .{ "^", .caret },
    .{ "&", .ampersand },
    .{ "<", .angle_bracket_left },
    .{ "<=", .angle_bracket_left_equal },
    .{ "<<", .angle_bracket_angle_bracket_left },
    .{ ">", .angle_bracket_right },
    .{ ">=", .angle_bracket_right_equal },
    .{ ">>", .angle_bracket_angle_bracket_right },
    .{ "~", .tilde },

    .{ ":", .colon },
    .{ ",", .comma },
});

pub const Scope = u32;
pub const TokenState = enum {
    start,

    identifier,

    string_literal,
    string_literal_end,
    string_literal_backslash,
    multiline_string_literal_start,
    multiline_string_literal,
    multiline_string_literal_backslash,
    multiline_string_literal_end_1,
    multiline_string_literal_end_2,
    multiline_string_literal_end,
    char_literal,
    char_literal_backslash,
    char_literal_hex_escape,
    char_literal_unicode_escape_saw_u,
    char_literal_unicode_escape,
    // char_literal_unicode_invalid,
    // char_literal_unicode,
    char_literal_end,
    backslash,

    colon,
    comma,
    l_paren,
    r_paren,
    l_bracket,
    r_bracket,
    equal,
    equal_angle_bracket_right,
    bang,
    bang_equal,
    equal_equal,
    pipe,
    pipe_pipe,
    pipe_equal,
    minus,
    minus_equal,
    asterisk,
    asterisk_asterisk,
    asterisk_equal,
    question_mark,
    slash,
    slash_equal,
    tilde,
    line_comment_start,
    line_comment,
    doc_comment_start,
    doc_comment,
    int,
    int_exponent,
    int_period,
    float,
    float_exponent,
    ampersand,
    ampersand_equal,
    caret,
    caret_equal,
    percent,
    percent_equal,
    plus,
    plus_plus,
    plus_equal,
    angle_bracket_left,
    angle_bracket_angle_bracket_left,
    angle_bracket_left_equal,
    angle_bracket_right,
    angle_bracket_angle_bracket_right,
    angle_bracket_right_equal,
    period,
    period_2,
    period_3,
    period_asterisk,
    period_question,
    period_l_brace,
    period_r_brace,
};

pub const TokenType = enum {
    unkown,

    // invalid_periodasterisks,
    identifier,
    // func_init_name,
    // identifier_arg, //调用方法的参数值
    // identifier_param, //定义方法的参数定义
    number_literal,
    doc_comment,
    container_doc_comment,

    /// "\""
    string_literal,
    /// "\\"
    multiline_string_literal,
    /// "\'"
    char_literal,
    eof,
    builtin,
    /// "!"
    bang,
    /// "="
    equal,
    /// "=="
    equal_equal,
    /// "=>"
    equal_angle_bracket_right,
    /// "!="
    bang_equal,
    /// "("
    l_paren,
    /// ")"
    r_paren,
    /// ";"
    semicolon,
    /// "{"
    l_brace,
    /// "}"
    r_brace,
    /// "{}"
    l_brace_r_brace,
    /// "["
    l_bracket,
    /// "]"
    r_bracket,
    /// "."
    period,
    /// ".*"
    period_asterisk,
    /// ".?"
    period_question,
    /// ".{"
    period_l_brace,
    /// ".."
    ellipsis2,
    /// "..."
    ellipsis3,
    /// "|"
    pipe,
    /// "||"
    pipe_pipe,
    /// "|="
    pipe_equal,
    /// "%"
    percent,
    /// "%="
    percent_equal,
    /// "^"
    caret,
    /// "^="
    caret_equal,
    /// "+"
    plus,
    /// "++"
    plus_plus,
    /// "+="
    plus_equal,
    /// "-"
    minus,
    /// "-="
    minus_equal,
    /// "*"
    asterisk,
    /// "*="
    asterisk_equal,
    /// "**"
    asterisk_asterisk,
    /// "/"
    slash,
    /// "/="
    slash_equal,
    /// "&"
    ampersand,
    /// "&="
    ampersand_equal,
    arrow,
    /// ":"
    colon,
    /// ","
    comma,
    /// "?"
    question_mark,
    /// "<"
    angle_bracket_left,
    /// "<="
    angle_bracket_left_equal,
    /// "<<"
    angle_bracket_angle_bracket_left,
    /// ">"
    angle_bracket_right,
    /// ">="
    angle_bracket_right_equal,
    /// ">>"
    angle_bracket_angle_bracket_right,
    /// "~"
    tilde,

    keyword_align,
    keyword_and,
    keyword_asm,
    keyword_code,
    keyword_async,
    keyword_await,
    keyword_break,
    keyword_callconv,
    keyword_catch,
    keyword_comptime,
    keyword_const,
    keyword_continue,
    keyword_defer,
    keyword_errdefer,
    keyword_else,
    keyword_enum,
    keyword_error,
    // keyword_false,
    keyword_fn,
    keyword_func,
    keyword_struct,
    keyword_if,
    keyword_for,
    keyword_in,
    keyword_inline,
    keyword_import,
    // keyword_null,
    keyword_pub,
    keyword_or,
    keyword_resume,
    keyword_return,
    keyword_switch,
    keyword_try,
    keyword_test,
    // keyword_true,
    // keyword_undefined,
    // keyword_unreachable,
    keyword_union,
    keyword_var,
    //keyword_void,
    keyword_while,
};

pub const Error = struct {
    tag: Tag,
    statement: Statement,
    token_index: TokenIndex,
    func_name: Str,
    line_no: usize,
    column_no: usize,
    error_text: Str,

    pub const Tag = enum {
        invalid_code,
        invalid_catch_code,
        expected_r_brace,
        expected_if_expression,
        expected_identifier,
        expected_identifier_value,
        expected_fn_result,
        expected_capitalization_for_container_name,
        expected_no_capitalization_for_function_name,
        invalid_token_type,
        invalid_symbol_type,
        invalid_operator,
        expected_data_type,
        expected_array_type,
        expected_semicolon,
        unknow_code_type,
        invalid_code_type,
        invalid_space,
        redeclaration_of_variable,

        asterisk_after_ptr_deref,
        chained_comparison_operators,
        decl_between_fields,
        expected_block,
        expected_block_or_assignment,
        expected_block_or_expr,
        expected_block_or_field,
        expected_container_members,
        expected_expr,
        expected_expr_or_assignment,
        expected_expr_or_var_decl,
        expected_fn,
        expected_inlinable,
        expected_labelable,
        expected_param_list,
        expected_prefix_expr,
        expected_primary_type_expr,
        expected_pub_item,
        expected_return_type,
        expected_semi_or_else,
        expected_semi_or_lbrace,
        expected_statement,
        expected_suffix_op,
        expected_var_decl,
        expected_var_decl_or_fn,
        expected_loop_payload,
        extern_fn_body,
        extra_addrspace_qualifier,
        extra_align_qualifier,
        extra_allowzero_qualifier,
        extra_const_qualifier,
        extra_volatile_qualifier,
        ptr_mod_on_array_child_type,
        invalid_bit_range,
        same_line_doc_comment,
        unattached_doc_comment,
        test_doc_comment,
        comptime_doc_comment,
        varargs_nonfinal,
        expected_continue_expr,
        expected_semi_after_decl,
        expected_semi_after_stmt,
        expected_comma_after_field,
        expected_comma_after_arg,
        expected_comma_after_initializer,
        expected_comma_after_switch_prong,
        expected_comma_after_for_operand,
        expected_comma_after_capture,
        expected_initializer,
        mismatched_binary_op_whitespace,
        invalid_ampersand_ampersand,
        c_style_container,
        expected_var_const,
        wrong_equal_var_decl,
        var_const_decl,
        extra_for_capture,
        for_input_not_captured,
    };
};
pub const ErrorTable = std.enums.directEnumArrayDefault(Error.Tag, Str, "", 0, .{
    .invalid_code = "invalid_code",
    .invalid_catch_code = "invalid_catch_code",
    .expected_r_brace = "expected_r_brace",
    .expected_if_expression = "expected_if_expression",
    .expected_identifier = "expected_identifier",
    .expected_identifier_value = "expected_identifier_value",
    .expected_fn_result = "expected_fn_result",
    .expected_capitalization_for_container_name = "expected_capitalization_for_container_name",
    .expected_no_capitalization_for_function_name = "expected_no_capitalization_for_function_name",
    .invalid_token_type = "invalid_token_type",
    .invalid_symbol_type = "invalid_symbol_type",
    .invalid_operator = "invalid_operator",
    .expected_data_type = "expected_data_type",
    .expected_array_type = "expected_array_type",
    .expected_semicolon = "expected_semicolon",
    .unknow_code_type = "unknow_code_type",
    .invalid_code_type = "invalid_code_type",
    .invalid_space = "invalid_space",
    .redeclaration_of_variable = "redeclaration_of_variable",
});
