const std = @import("std");

pub fn t(comptime V: type) type {
    return struct {
        const Self = @This();
        map: std.StaticStringMap(V),

        /// use std.StaticStringMap, not need free
        pub fn a(comptime static_value: anytype) Self {
            const map = std.StaticStringMap(V).initComptime(static_value);
            return Self{
                .map = map,
            };
        }

        /// Check if the map contains a key
        pub fn hasKey(self: Self, key: []const u8) bool {
            return self.map.has(key);
        }
        pub fn get(self: Self, key: []const u8) ?V {
            return self.map.get(key);
        }
        pub fn keys(self: Self) []const []const u8 {
            return try self.map.keys();
        }
        pub fn values(self: Self) []const V {
            return self.map.values();
        }
    };
}

const StaticStringMap = @This();
