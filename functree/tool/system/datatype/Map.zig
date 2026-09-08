const Memory = @import("../Memory.zig");

const std = @import("std");

pub fn t(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        memory: *Memory,
        map: std.AutoHashMap(K, V),

        /// free memory by caller.
        pub fn a(memory: *Memory) Self {
            const map = std.AutoHashMap(K, V).init(memory.allocator());
            return Self{
                .memory = memory,
                .map = map,
            };
        }
        /// Release the backing array and invalidate this map.
        /// This does *not* deinit keys, values, or the context!
        /// If your keys or values need to be released, ensure
        /// that that is done before calling this function.
        pub fn d(self: *Self) void {
            self.map.deinit();
        }

        pub fn clone(self: Self) !Self {
            return try self.map.clone();
        }

        /// Return the number of items in the map.
        pub fn count(self: Self) u32 {
            return self.map.count();
        }
        /// Check if the map contains a key
        pub fn hasKey(self: Self, key: K) bool {
            return self.map.contains(key);
        }
        pub fn get(self: Self, key: K) ?V {
            return self.map.get(key);
        }
        pub fn getPtr(self: Self, key: K) ?*V {
            return self.map.getPtr(key);
        }
        pub fn add(self: *Self, key: K, value: V) !void {
            return try self.map.put(key, value);
        }
        pub fn remove(self: *Self, key: K) bool {
            return self.map.remove(key);
        }
        pub fn keys(self: Self) ![]const K {
            var key_array = try self.memory.alloc2(K, self.count());
            var iter = self.map.keyIterator();
            var i: usize = 0;
            while (iter.next()) |key| {
                key_array[i] = key.*;
                i += 1;
            }
            return key_array;
        }
        pub fn values(self: Self) ![]const V {
            var value_array = try self.memory.alloc2(V, self.count());
            var iter = self.map.valueIterator();
            var i: usize = 0;
            while (iter.next()) |value| {
                value_array[i] = value.*;
                i += 1;
            }
            return value_array;
        }
    };
}

const Map = @This();
