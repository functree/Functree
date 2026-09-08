const Memory = @import("../Memory.zig");
const String = @import("String.zig");
const List = @import("List.zig");

pub const control_code = std.ascii.control_code;

const std = @import("std");
const unicode = std.unicode;
const Utf8Iterator = unicode.Utf8Iterator;
const ascii = std.ascii;

pub fn isControl(value: u8) bool {
    return ascii.isControl(value);
}

pub fn isDigit(value: u8) bool {
    return ascii.isDigit(value);
}

pub fn isLower(value: u8) bool {
    return ascii.isLower(value);
}

pub fn isUpper(value: u8) bool {
    return ascii.isUpper(value);
}

pub fn isHex(value: u8) bool {
    return ascii.isHex(value);
}

pub fn isAscii(value: u8) bool {
    return ascii.isAscii(value);
}

pub fn toLower(value: u8) u8 {
    return ascii.toLower(value);
}

pub fn toUpper(value: u8) u8 {
    return ascii.toUpper(value);
}

pub fn isUtf8Codepoint(value: u21) bool {
    return unicode.utf8ValidCodepoint(value);
}

pub fn utf8Encode(value: u21) ![]u8 {
    var output: [4]u8 = undefined;
    const byte_count = try unicode.utf8Encode(value, output[0..]);
    return output[0..byte_count];
}

pub fn utf8Decode(value: []const u8) !u21 {
    return try unicode.utf8Decode(value);
}

pub fn getUtf8CharLength(first_byte: u8) !u3 {
    return try unicode.utf8ByteSequenceLength(first_byte);
}

pub fn getUtf8Iter(value: []const u8) !Utf8Iterator {
    return (try unicode.Utf8View.init(value)).iterator();
}

pub fn getUtf8CharList(memory: *Memory, value: []const u8) !List.t([]const u8) {
    var list = List.t([]const u8).a(memory);
    var iter = (try unicode.Utf8View.init(value)).iterator();
    while (iter.nextCodepointSlice()) |string| {
        try list.add(try String.copyStr(memory, string));
    }
    return list;
}

const Char = @This();
