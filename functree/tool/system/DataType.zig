pub const Char = @import("datatype/Char.zig");
// pub const Date = @import("functree_system_datatype_Date.zig");
// pub const DateTime = @import("functree_system_datatype_DateTime.zig");
// pub const Float = @import("functree_system_datatype_Float.zig");
// pub const Integer = @import("functree_system_datatype_Integer.zig");
// pub const Json = @import("functree_system_datatype_Json.zig");
pub const List = @import("datatype/List.zig");
pub const Map = @import("datatype/Map.zig");
pub const StringMap = @import("datatype/StringMap.zig");
pub const StaticStringMap = @import("datatype/StaticStringMap.zig");
// pub const Result = @import("functree_system_datatype_Result.zig");
pub const String = @import("datatype/String.zig");
// pub const Tensor = @import("functree_system_datatype_Tensor.zig");

const std = @import("std");
const builtin = std.builtin;

pub inline fn typeOf(value: anytype) type {
    return @TypeOf(value);
}
pub inline fn typeInfo(comptime T: type) builtin.Type {
    return @typeInfo(T);
}
pub inline fn typeName(T: type) []const u8 {
    return @typeName(T);
}
pub inline fn sizeOf(comptime T: type) comptime_int {
    return @sizeOf(T);
}
pub inline fn ptrCast(T: anytype) type {
    return @ptrCast(T);
}
pub inline fn alignCast(T: anytype) type {
    return @alignCast(T);
}

pub inline fn abs(value: anytype) @TypeOf(value) {
    return @abs(value);
}
pub inline fn sqrt(value: anytype) @TypeOf(value) {
    return @sqrt(value);
}
pub inline fn sin(value: anytype) @TypeOf(value) {
    return @sin(value);
}
pub inline fn cos(value: anytype) @TypeOf(value) {
    return @cos(value);
}
pub inline fn tan(value: anytype) @TypeOf(value) {
    return @tan(value);
}

pub inline fn ceil(value: anytype) @TypeOf(value) {
    return @ceil(value);
}
pub inline fn floor(value: anytype) @TypeOf(value) {
    return @floor(value);
}
pub inline fn round(value: anytype) @TypeOf(value) {
    return @round(value);
}

pub inline fn exp(value: anytype) @TypeOf(value) {
    return @exp(value);
}
pub inline fn exp2(value: anytype) @TypeOf(value) {
    return @exp2(value);
}
pub inline fn log(value: anytype) @TypeOf(value) {
    return @log(value);
}
pub inline fn log2(value: anytype) @TypeOf(value) {
    return @log2(value);
}
pub inline fn log10(value: anytype) @TypeOf(value) {
    return std.math.log10(value);
}

pub inline fn min(value1: anytype, value2: anytype) @TypeOf(value1) {
    return @min(value1, value2);
}
pub inline fn max(value1: anytype, value2: anytype) @TypeOf(value1) {
    return @max(value1, value2);
}
pub inline fn mod(value1: anytype, value2: anytype) @TypeOf(value1) {
    return @mod(value1, value2);
}
pub inline fn pow(comptime T: type, value1: anytype, value2: anytype) T {
    return std.math.pow(T, value1, value2);
}

pub inline fn intCast(comptime T: type, value: anytype) T {
    return @as(T, @intCast(value));
}
pub inline fn intFromEnum(comptime T: type, value: anytype) T {
    return @as(T, @intFromEnum(value));
}
pub inline fn intFromFloat(comptime T: type, value: anytype) T {
    return @as(T, @intFromFloat(value));
}

pub inline fn floatCast(comptime T: type, value: anytype) T {
    return @as(T, @floatCast(value));
}
pub inline fn floatFromInt(comptime T: type, value: anytype) T {
    return @as(T, @floatFromInt(value));
}

const DataType = @This();
