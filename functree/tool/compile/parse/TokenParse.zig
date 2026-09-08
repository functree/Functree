const System = @import("../../System.zig");
const Memory = System.Memory;
const Io = System.Io;
const Console = Io.Console;
const DataType = System.DataType;
const Char = DataType.Char;
const Integer = DataType.Integer;
const String = DataType.String;

const Token = @import("../func/Token.zig");
const TokenType = Token.TokenType;
const CharIndex = Token.CharIndex;
const KeywordMap = Token.KeywordMap;

memory: *Memory,
buffer: []const []const u8,
index: CharIndex,
token_pre: ?Token = null,

pub fn a(memory: *Memory, buffer: []const []const u8) TokenParse {
    return .{
        .memory = memory,
        .buffer = buffer,
        .index = 0,
    };
}

const State = enum {
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
    char_literal_end,
    backslash,
    l_paren,
    l_brace,
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
    line_comment,
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
    angle_bracket_angle_bracket_left_equal,
    angle_bracket_left_equal,
    angle_bracket_right,
    angle_bracket_angle_bracket_right,
    angle_bracket_angle_bracket_right_equal,
    angle_bracket_right_equal,
    period,
    period_2,
    period_3,
    period_asterisk,
    period_question,
    period_l_brace,
};

pub fn next(self: *TokenParse) TokenError!Token {
    var seen_escape_digits: usize = undefined;
    var token = Token.a(self.index);
    var state = State.start;
    while (self.index < self.buffer.len) {
        const utf8_char = self.buffer[self.index];
        const c = Char.utf8Decode(utf8_char) catch |err| {
            Console.print2("utf8_char_decode: {s}, error: {any}", .{ utf8_char, err });
            return TokenError.utf8_char_decode_error;
        };
        switch (state) {
            .start => switch (c) {
                0 => {
                    return TokenError.exist_eof;
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    token.start_char = self.index;
                    continue;
                },
                'a'...'z', 'A'...'Z', '_', '\u{4E00}'...'\u{9F00}' => {
                    state = .identifier;
                    token.token_type = .identifier;
                },
                '0'...'9' => {
                    state = .int;
                    token.token_type = .number_literal;
                },
                '=' => {
                    state = .equal;
                    token.token_type = .equal;
                },
                '!' => {
                    state = .bang;
                    token.token_type = .bang;
                },
                '|' => {
                    state = .pipe;
                    token.token_type = .pipe;
                },
                '%' => {
                    state = .percent;
                    token.token_type = .percent;
                },
                '?' => {
                    state = .question_mark;
                    token.token_type = .question_mark;
                },
                '*' => {
                    state = .asterisk;
                    token.token_type = .asterisk;
                },
                '+' => {
                    state = .plus;
                    token.token_type = .plus;
                },
                '-' => {
                    state = .minus;
                    token.token_type = .minus;
                },
                '/' => {
                    state = .slash;
                    token.token_type = .slash;
                },
                '&' => {
                    state = .ampersand;
                    token.token_type = .ampersand;
                },
                '<' => {
                    state = .angle_bracket_left;
                    token.token_type = .angle_bracket_left;
                },
                '>' => {
                    state = .angle_bracket_right;
                    token.token_type = .angle_bracket_right;
                },
                '^' => {
                    state = .caret;
                    token.token_type = .caret;
                },
                '.' => {
                    state = .period;
                    token.token_type = .period;
                },
                '"' => {
                    state = .string_literal;
                    token.token_type = .string_literal;
                },
                '\'' => {
                    state = .char_literal;
                    token.token_type = .char_literal;
                },
                '\\' => {
                    state = .backslash;
                },
                ':' => {
                    token.token_type = .colon;
                    try self.incIndex(&token);
                    break;
                },
                '~' => {
                    token.token_type = .tilde;
                    try self.incIndex(&token);
                    break;
                },
                ',' => {
                    token.token_type = .comma;
                    try self.incIndex(&token);
                    break;
                },
                ';' => {
                    token.token_type = .semicolon;
                    try self.incIndex(&token);
                    break;
                },
                '(' => {
                    token.token_type = .l_paren;
                    try self.incIndex(&token);
                    break;
                },
                ')' => {
                    token.token_type = .r_paren;
                    try self.incIndex(&token);
                    break;
                },
                '[' => {
                    token.token_type = .l_bracket;
                    try self.incIndex(&token);
                    break;
                },
                ']' => {
                    token.token_type = .r_bracket;
                    try self.incIndex(&token);
                    break;
                },
                '{' => {
                    token.token_type = .l_brace;
                    if (self.token_pre != null and self.token_pre.?.token_type == .identifier) {
                        try self.incIndex(&token);
                        break;
                    } else {
                        state = .l_brace;
                    }
                },
                '}' => {
                    token.token_type = .r_brace;
                    try self.incIndex(&token);
                    break;
                },
                else => {
                    return TokenError.start_with_wrong_char;
                },
            },
            .identifier => switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '_', '\u{4E00}'...'\u{9F00}' => {},
                else => {
                    if (self.token_pre == null or self.token_pre.?.token_type != .period) {
                        const token_type = KeywordMap.get(token.text);
                        if (token_type != null) token.token_type = token_type.?;
                    }
                    break;
                },
            },
            .backslash => {},
            .l_brace => switch (c) {
                '}' => {
                    token.token_type = .l_brace_r_brace;
                    try self.incIndex(&token);
                    break;
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    token.start_char = self.index;
                    continue;
                },
                else => {
                    break;
                },
            },
            .equal => switch (c) {
                '=' => {
                    state = .equal_equal;
                    token.token_type = .equal_equal;
                },
                '>' => {
                    state = .equal_angle_bracket_right;
                    token.token_type = .equal_angle_bracket_right;
                },
                else => {
                    break;
                },
            },
            .bang => switch (c) {
                '=' => {
                    state = .bang_equal;
                    token.token_type = .bang_equal;
                },
                else => {
                    break;
                },
            },
            .angle_bracket_left => switch (c) {
                '<' => {
                    state = .angle_bracket_angle_bracket_left;
                    token.token_type = .angle_bracket_angle_bracket_left;
                },
                '=' => {
                    state = .angle_bracket_left_equal;
                    token.token_type = .angle_bracket_left_equal;
                },
                else => {
                    break;
                },
            },
            .angle_bracket_angle_bracket_left => switch (c) {
                '=' => {
                    state = .angle_bracket_angle_bracket_left_equal;
                    token.token_type = .angle_bracket_angle_bracket_left_equal;
                },
                else => {
                    break;
                },
            },
            .angle_bracket_right => switch (c) {
                '>' => {
                    state = .angle_bracket_angle_bracket_right;
                    token.token_type = .angle_bracket_angle_bracket_right;
                },
                '=' => {
                    state = .angle_bracket_right_equal;
                    token.token_type = .angle_bracket_right_equal;
                },
                else => {
                    break;
                },
            },
            .angle_bracket_angle_bracket_right => switch (c) {
                '=' => {
                    state = .angle_bracket_angle_bracket_right_equal;
                    token.token_type = .angle_bracket_angle_bracket_right_equal;
                },
                else => {
                    break;
                },
            },
            .period => switch (c) {
                '.' => {
                    state = .period_2;
                    token.token_type = .ellipsis2;
                },
                '*' => {
                    state = .period_asterisk;
                    token.token_type = .period_asterisk;
                },
                '?' => {
                    state = .period_question;
                    token.token_type = .period_question;
                },
                '{' => {
                    state = .period_l_brace;
                    token.token_type = .period_l_brace;
                },
                else => {
                    break;
                },
            },
            .period_2 => switch (c) {
                '.' => {
                    state = .period_3;
                    token.token_type = .ellipsis3;
                },
                else => {
                    break;
                },
            },
            .period_asterisk => switch (c) {
                '*' => {
                    return TokenError.invalid_asterisk;
                },
                else => {
                    break;
                },
            },
            .period_question => switch (c) {
                '?' => {
                    return TokenError.invalid_question;
                },
                else => {
                    break;
                },
            },
            .plus => switch (c) {
                '+' => {
                    state = .plus_plus;
                    token.token_type = .plus_plus;
                },
                '=' => {
                    state = .plus_equal;
                    token.token_type = .plus_equal;
                },
                else => {
                    break;
                },
            },
            .minus => switch (c) {
                '=' => {
                    state = .minus_equal;
                    token.token_type = .minus_equal;
                },
                else => {
                    break;
                },
            },
            .asterisk => switch (c) {
                '*' => {
                    state = .asterisk_asterisk;
                    token.token_type = .asterisk_asterisk;
                },
                '=' => {
                    state = .asterisk_equal;
                    token.token_type = .asterisk_equal;
                },
                else => {
                    break;
                },
            },
            .percent => switch (c) {
                '=' => {
                    state = .percent_equal;
                    token.token_type = .percent_equal;
                },
                else => {
                    break;
                },
            },
            .ampersand => switch (c) {
                '=' => {
                    state = .ampersand_equal;
                    token.token_type = .ampersand_equal;
                },
                else => {
                    break;
                },
            },
            .pipe => switch (c) {
                '|' => {
                    state = .pipe_pipe;
                    token.token_type = .pipe_pipe;
                },
                '=' => {
                    state = .pipe_equal;
                    token.token_type = .pipe_equal;
                },
                else => {
                    break;
                },
            },
            .caret => switch (c) {
                '=' => {
                    state = .caret_equal;
                    token.token_type = .caret_equal;
                },
                else => {
                    break;
                },
            },
            .int => switch (c) {
                '.' => state = .int_period,
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {},
                'e', 'E', 'p', 'P' => state = .int_exponent,
                else => {
                    break;
                },
            },
            .int_exponent => switch (c) {
                '-', '+' => {
                    state = .float;
                },
                else => {
                    state = .int;
                },
            },
            .int_period => switch (c) {
                '.' => {
                    token.text = token.text[0 .. token.text.len - 1];
                    self.index -= 1;
                    break;
                },
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    state = .float;
                },
                'e', 'E', 'p', 'P' => state = .float_exponent,
                else => {
                    break;
                },
            },
            .float => switch (c) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {},
                'e', 'E', 'p', 'P' => state = .float_exponent,
                else => {
                    break;
                },
            },
            .float_exponent => switch (c) {
                '-', '+' => state = .float,
                else => {
                    state = .float;
                },
            },
            .char_literal => switch (c) {
                0, '\n', 0xf8...0xff => {
                    return TokenError.invalid_char_literal;
                },
                '\'' => {
                    state = .multiline_string_literal_start;
                },
                '\\' => {
                    state = .char_literal_backslash;
                },
                else => {
                    state = .char_literal_end;
                },
            },
            .char_literal_backslash => switch (c) {
                0, '\n' => {
                    return TokenError.invalid_char_literal_backslash;
                },
                'x' => {
                    state = .char_literal_hex_escape;
                    seen_escape_digits = 0;
                },
                'u' => {
                    state = .char_literal_unicode_escape_saw_u;
                },
                else => {
                    state = .char_literal_end;
                },
            },
            .char_literal_hex_escape => switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    seen_escape_digits += 1;
                    if (seen_escape_digits == 2) {
                        state = .char_literal_end;
                    }
                },
                else => {
                    return TokenError.invalid_char_literal_hex_escape;
                },
            },
            .char_literal_unicode_escape_saw_u => switch (c) {
                '{' => {
                    state = .char_literal_unicode_escape;
                },
                else => {
                    return TokenError.invalid_char_literal_unicode_escape_saw_u;
                },
            },
            .char_literal_unicode_escape => switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {},
                '}' => {
                    state = .char_literal_end;
                },
                else => {
                    return TokenError.invalid_char_literal_unicode_escape;
                },
            },
            .char_literal_end => switch (c) {
                '.' => {
                    break;
                },
                '\'' => {},
                else => {
                    if (token.token_type == .char_literal) {
                        break;
                    } else {
                        return TokenError.invalid_char_literal_end;
                    }
                },
            },
            .multiline_string_literal_start => switch (c) {
                '\'' => {
                    state = .multiline_string_literal;
                    token.token_type = .multiline_string_literal;
                },
                else => {
                    return TokenError.invalid_multiline_string_literal;
                },
            },
            .multiline_string_literal => switch (c) {
                '\'' => {
                    state = .multiline_string_literal_end_1;
                },
                else => {},
            },
            .multiline_string_literal_end_1 => switch (c) {
                '\'' => {
                    state = .multiline_string_literal_end_2;
                },
                else => {
                    state = .multiline_string_literal;
                },
            },
            .multiline_string_literal_end_2 => switch (c) {
                '\'' => {
                    state = .multiline_string_literal_end;
                },
                else => {
                    state = .multiline_string_literal;
                },
            },
            .multiline_string_literal_backslash => switch (c) {
                0 => {
                    return TokenError.invalid_multiline_string_literal_backslash;
                },
                else => {
                    state = .multiline_string_literal;
                },
            },
            .multiline_string_literal_end => switch (c) {
                '\'' => {
                    return TokenError.invalid_multiline_string_literal_end;
                },
                else => {
                    break;
                },
            },
            .string_literal => switch (c) {
                '\\' => {
                    state = .string_literal_backslash;
                },
                '"' => {
                    state = .string_literal_end;
                },
                0, '\n' => {
                    return TokenError.invalid_string_literal;
                },
                else => {},
            },
            .string_literal_backslash => switch (c) {
                0, '\n' => {
                    return TokenError.invalid_string_literal_backslash;
                },
                else => {
                    state = .string_literal;
                },
            },
            .string_literal_end => switch (c) {
                0, '\n' => {
                    return TokenError.invalid_string_literal_end;
                },
                else => {
                    break;
                },
            },
            .slash => switch (c) {
                '/' => {
                    state = .line_comment;
                },
                '=' => {
                    state = .slash_equal;
                    token.token_type = .slash_equal;
                },
                else => {
                    break;
                },
            },
            .line_comment => switch (c) {
                '\n' => {
                    state = .start;
                    self.index += 1;
                    token = Token.a(self.index);
                    continue;
                },
                else => {},
            },
            else => {
                break;
            },
        }
        try self.incIndex(&token);
    }
    return token;
}

inline fn incIndex(self: *TokenParse, token: *Token) TokenError!void {
    const text = self.buffer[self.index];
    token.text = String.concatStr(self.memory, &.{ token.text, text }) catch |err| {
        Console.print2("TokenParse inc char index: {d}, error: {any}", .{ self.index, err });
        return TokenError.concat_str_out_of_memory;
    };
    self.index += 1;
    token.end_char = self.index;
}
pub const TokenError = error{
    utf8_char_decode_error,
    exist_eof,
    start_with_wrong_char,
    invalid_asterisk,
    invalid_question,
    invalid_char_literal,
    invalid_char_literal_backslash,
    invalid_char_literal_hex_escape,
    invalid_char_literal_unicode_escape_saw_u,
    invalid_char_literal_unicode_escape,
    invalid_char_literal_end,
    invalid_multiline_string_literal,
    invalid_multiline_string_literal_backslash,
    invalid_multiline_string_literal_end,
    invalid_string_literal,
    invalid_string_literal_backslash,
    invalid_string_literal_end,
    concat_str_out_of_memory,
};
pub fn getErrorText(err: TokenError) []const u8 {
    switch (err) {
        TokenError.utf8_char_decode_error => return "utf8_char_decode_error",
        TokenError.exist_eof => return "exist_eof",
        TokenError.start_with_wrong_char => return "start_with_wrong_char",
        TokenError.invalid_asterisk => return "invalid_asterisk",
        TokenError.invalid_question => return "invalid_question",
        TokenError.invalid_char_literal => return "invalid_char_literal",
        TokenError.invalid_char_literal_backslash => return "invalid_char_literal_backslash",
        TokenError.invalid_char_literal_hex_escape => return "invalid_char_literal_hex_escape",
        TokenError.invalid_char_literal_unicode_escape_saw_u => return "invalid_char_literal_unicode_escape_saw_u",
        TokenError.invalid_char_literal_unicode_escape => return "invalid_char_literal_unicode_escape",
        TokenError.invalid_char_literal_end => return "invalid_char_literal_end",
        TokenError.invalid_multiline_string_literal => return "invalid_multiline_string_literal",
        TokenError.invalid_multiline_string_literal_backslash => return "invalid_multiline_string_literal_backslash",
        TokenError.invalid_multiline_string_literal_end => return "invalid_multiline_string_literal_end",
        TokenError.invalid_string_literal => return "invalid_string_literal",
        TokenError.invalid_string_literal_backslash => return "invalid_string_literal_backslash",
        TokenError.invalid_string_literal_end => return "invalid_string_literal_end",
        TokenError.concat_str_out_of_memory => return "concat_str_out_of_memory",
    }
}

const TokenParse = @This();
