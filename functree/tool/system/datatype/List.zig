const Memory = @import("../Memory.zig");

const std = @import("std");

pub fn t(comptime T: type) type {
    return struct {
        const Self = @This();
        memory: *Memory,
        list: std.ArrayList(T) = .empty,

        /// free memory by caller.
        pub fn a(memory: *Memory) Self {
            return Self{
                .memory = memory,
            };
        }
        pub fn a2(memory: *Memory, slice: []T) !Self {
            var self = Self{
                .memory = memory,
            };
            try self.list.insertSlice(self.memory.allocator(), 0, slice);
            return self;
        }
        /// Release all allocated memory
        pub fn d(self: *Self) void {
            self.list.deinit(self.memory.allocator());
            self.* = undefined;
        }

        pub fn clone(self: Self) !Self {
            const list = try self.list.clone(self.memory.allocator());
            return Self{
                .memory = self.memory,
                .list = list,
            };
        }

        pub fn values(self: Self) []T {
            return self.list.items;
        }
        pub fn count(self: Self) usize {
            return self.list.items.len;
        }
        pub fn add(self: *Self, value: T) !void {
            try self.list.append(self.memory.allocator(), value);
        }
        pub fn add2(self: *Self, i: usize, value: T) !void {
            try self.list.insert(self.memory.allocator(), i, value);
        }
        pub fn addArray(self: *Self, slice: []const T) !void {
            try self.list.appendSlice(self.memory.allocator(), slice);
        }
        pub fn addArray2(self: *Self, i: usize, slice: []const T) !void {
            try self.list.insertSlice(self.memory.allocator(), i, slice);
        }
        pub fn toArray(self: *Self) ![]T {
            return self.list.toOwnedSlice(self.memory.allocator());
        }
    };
}

const List = @This();
