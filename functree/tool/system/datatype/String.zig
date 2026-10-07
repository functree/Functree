const Memory = @import("../Memory.zig");
const Char = @import("Char.zig");
const List = @import("List.zig");

const std = @import("std");
const unicode = std.unicode;

memory: *Memory,
bytes: []u8,

pub fn a(memory: *Memory, buffer: []const u8) !String {
    const self = String{
        .memory = memory,
        .bytes = try memory.allocator().dupe(u8, buffer),
    };
    return self;
}

pub fn d(self: *String) void {
    self.memory.free2(self.bytes);
}

pub fn clone(self: String) !String {
    const buffer = try self.memory.allocator().dupe(u8, self.bytes);
    return String{
        .memory = self.memory,
        .bytes = buffer,
    };
}
pub fn concat(self: String, value: String) !String {
    const buffer = try std.mem.concat(self.memory.allocator(), u8, &.{ self.bytes, value.bytes });
    return String{
        .memory = self.memory,
        .bytes = buffer,
    };
}
pub fn join(self: String, separator: []const u8, value: String) !String {
    const buffer = try std.mem.join(self.memory.allocator(), separator, &.{ self.bytes, value.bytes });
    return String{
        .memory = self.memory,
        .bytes = buffer,
    };
}

pub fn indexOf(self: String, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, self.bytes, needle);
}

pub fn lastIndexOf(self: String, needle: []const u8) ?usize {
    return std.mem.lastIndexOf(u8, self.bytes, needle);
}

pub fn equal(self: String, value: String) bool {
    return std.mem.eql(u8, self.bytes, value.bytes);
}
pub fn count(self: String, needle: []const u8) usize {
    return std.mem.count(u8, self.bytes, needle);
}

pub fn toCharArray(self: String) ![]const []const u8 {
    var list = List.t([]u8).a(self.memory);
    var it = try Char.getUtf8Iter(self.bytes);
    while (it.nextCodepointSlice()) |buffer| {
        try list.add(try self.memory.allocator().dupe(u8, buffer));
    }
    return list.toArray();
}

pub fn toCharList(self: String) !List {
    var list = List.t([]u8).a(self.memory);
    var it = try Char.getUtf8Iter(self.bytes);
    while (it.nextCodepointSlice()) |buffer| {
        try list.add(try self.memory.allocator().dupe(u8, buffer));
    }
    return list;
}

pub fn toStr(self: String) []const u8 {
    return self.bytes[0..];
}

pub fn replace(self: String, needle: []const u8, replacement: []const u8) !String {
    const size = std.mem.replacementSize(u8, self.bytes[0..], needle, replacement);
    const buffer = self.memory.alloc2(u8, size) catch |err| return err;
    _ = std.mem.replace(u8, self.bytes[0..], needle, replacement, buffer);
    return String{
        .memory = self.memory,
        .bytes = buffer,
    };
}

pub fn startWith(self: String, needle: []const u8) bool {
    return std.mem.startsWith(u8, self.bytes, needle);
}
pub fn endWith(self: String, needle: []const u8) bool {
    return std.mem.endsWith(u8, self.bytes, needle);
}

pub fn split(self: String, delimiter: []const u8) ![]String {
    var splitArr = List.t(String).a(self.memory);
    var it = std.mem.splitSequence(u8, self.bytes, delimiter);
    while (it.next()) |item| {
        const string = String{
            .memory = self.memory,
            .bytes = try self.memory.allocator().dupe(u8, item),
        };
        try splitArr.add(string);
    }
    return try splitArr.toArray();
}

pub fn subStr(self: String, start: usize, end: usize) ![]const u8 {
    return try self.memory.allocator().dupe(u8, self.bytes[start..end]);
}
pub fn subString(self: String, start: usize, end: usize) !String {
    const buffer = try self.memory.allocator().dupe(u8, self.bytes[start..end]);
    return String{
        .memory = self.memory,
        .bytes = buffer,
    };
}

pub fn trim(self: String) !String {
    const buffer = std.mem.trim(u8, self.bytes, " \r\n");
    return String{
        .memory = self.memory,
        .bytes = try self.memory.allocator().dupe(u8, buffer),
    };
}
pub fn trimLeft(self: String) !String {
    const buffer = std.mem.trimStart(u8, self.bytes, " \r\n");
    return String{
        .memory = self.memory,
        .bytes = try self.memory.allocator().dupe(u8, buffer),
    };
}
pub fn trimRight(self: String) !String {
    const buffer = std.mem.trimEnd(u8, self.bytes, " \n");
    return String{
        .memory = self.memory,
        .bytes = try self.memory.allocator().dupe(u8, buffer),
    };
}

pub fn isEmptyStr(value: ?[]const u8) bool {
    if (value != null) {
        const value2 = trimStr(value.?);
        if (value2.len > 0) return false;
    }
    return true;
}

pub fn isNumberStr(value: []const u8) bool {
    if (value.len == 0) return false;
    var i: usize = 0;
    var hasDecimal = false;
    var hasSign = false;
    if (value[i] == '+' or value[i] == '-') {
        hasSign = true;
        i += 1;
    }
    while (i < value.len) {
        const ch = value[i];
        i += 1;
        if (ch >= '0' and ch <= '9') {
            continue;
        }
        if (ch == '.') {
            if (hasDecimal) {
                return false;
            }
            hasDecimal = true;
            continue;
        }
        return false;
    }
    var singn_count: usize = 0;
    if (hasSign) singn_count = 1;
    return i > singn_count;
}

pub fn isUtf8Str(value: []const u8) bool {
    return unicode.utf8ValidateSlice(value);
}

pub fn copyStr(memory: *Memory, value: []const u8) ![]u8 {
    return try memory.allocator().dupe(u8, value);
}
pub fn copySubStr(memory: *Memory, value: []const u8, start: usize, end: usize) ![]const u8 {
    return try memory.allocator().dupe(u8, value[start..end]);
}

pub fn concatStr(memory: *Memory, slices: []const []const u8) ![]u8 {
    return try std.mem.concat(memory.allocator(), u8, slices);
}

pub fn joinStr(memory: *Memory, separator: []const u8, slices: []const []const u8) ![]u8 {
    return try std.mem.join(memory.allocator(), separator, slices);
}

pub fn formatStr(memory: *Memory, comptime fmt: []const u8, values: anytype) ![]u8 {
    return try memory.allocator().print(fmt, values);
}
pub fn formatStr2(buffer: []u8, comptime fmt: []const u8, values: anytype) ![]u8 {
    return try std.mem.print(buffer, fmt, values);
}

pub fn replaceStr(memory: *Memory, value: []const u8, needle: []const u8, replacement: []const u8) ![]u8 {
    const size = std.mem.replacementSize(u8, value, needle, replacement);
    const buffer = memory.alloc2(u8, size) catch |err| return err;
    _ = std.mem.replace(u8, value, needle, replacement, buffer);
    return buffer;
}

pub fn replaceStr2(buffer: []u8, value: []const u8, needle: []const u8, replacement: []const u8) []u8 {
    var i: usize = 0;
    var index: usize = 0;
    while (index < value.len) {
        if (std.mem.startsWith(u8, value[index..], needle)) {
            Memory.copy(buffer[i..][0..replacement.len], replacement);
            i += replacement.len;
            index += needle.len;
        } else {
            buffer[i] = value[index];
            i += 1;
            index += 1;
        }
    }
    return buffer[0..index];
}

pub fn countStr(value: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, value, needle);
}

pub fn equalStr(value1: []const u8, value2: []const u8) bool {
    return std.mem.eql(u8, value1, value2);
}

pub fn indexOfStr(value: []const u8, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, value, needle);
}

pub fn lastIndexOfStr(value: []const u8, needle: []const u8) ?usize {
    return std.mem.lastIndexOf(u8, value, needle);
}

pub fn splitStr(value: []const u8, delimiter: []const u8) ![]const []const u8 {
    var splitArr: std.ArrayList([]const u8) = .empty;
    defer splitArr.deinit(std.heap.page_allocator);

    var it = std.mem.splitSequence(u8, value, delimiter);
    while (it.next()) |item| {
        try splitArr.append(std.heap.page_allocator, item);
    }
    return try splitArr.toOwnedSlice(std.heap.page_allocator);
}

pub fn startWithStr(value: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, value, needle);
}
pub fn endWithStr(value: []const u8, needle: []const u8) bool {
    return std.mem.endsWith(u8, value, needle);
}
pub fn trimStr(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \t\r\n");
}
pub fn trimStr2(value: []const u8, value_to_strip: []const u8) []const u8 {
    return std.mem.trim(u8, value, value_to_strip);
}
pub fn trimLeftStr(value: []const u8) []const u8 {
    return std.mem.trimStart(u8, value, " \t\r\n");
}
pub fn trimRightStr(value: []const u8) []const u8 {
    return std.mem.trimEnd(u8, value, " \t\r\n");
}

const String = @This();
