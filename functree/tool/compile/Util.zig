const std = @import("std");

pub fn concat(allocator: std.mem.Allocator, slices: []const []const u8) ![]const u8 {
    const s = try std.mem.concat(allocator, u8, slices);
    return s;
}
pub fn copy(alloc: std.mem.Allocator, s: []const u8) ![]u8 {
    return alloc.dupe(u8, s);
}
pub fn isEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
