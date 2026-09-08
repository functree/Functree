const std = @import("std");
pub const Heap = std.heap.DebugAllocator(.{});

pub const Allocator = std.mem.Allocator;
pub const Alignment = std.mem.Alignment;
pub const Stack = std.heap.FixedBufferAllocator;
pub const HeapArena = std.heap.ArenaAllocator;

const FallbackAllocator = @import("memory/FallbackAllocator.zig");
const Io = @import("Io.zig");

heap: ?Heap = null,
heap_arena: ?HeapArena = null,
stack: ?Stack = null,
stack_heap: ?FallbackAllocator = null,
single_thread: bool = false,
is_stack: bool = false,
auto_free: bool = false,

threaded: ?std.Io.Threaded = null,

pub fn a() Memory {
    return Memory{
        .heap = .init,
    };
}

pub fn f(self: *Memory) void {
    self.heap_arena = HeapArena.init(self.heap.?.allocator());
    self.auto_free = true;
}

pub fn s(self: *Memory, buffer: []u8) void {
    if (self.heap_arena == null) self.f();
    self.aStackHeap(buffer, false);
}

pub fn ss(self: *Memory, buffer: []u8) void {
    if (self.heap_arena == null) self.f();
    self.aStackHeap(buffer, true);
}
fn aStackHeap(self: *Memory, buffer: []u8, single_thread: bool) void {
    const fallback = FallbackAllocator{
        .buffer = buffer,
        .fallback_allocator = self.heap_arena.?,
        .fixed_buffer_allocator = undefined,
        .single_thread = single_thread,
    };
    self.stack_heap = fallback;
    self.single_thread = single_thread;
}

pub fn d(self: *Memory) void {
    if (self.stack_heap != null) {
        _ = self.stack_heap.?.fallback_allocator.deinit();
    }
    if (self.heap_arena != null) {
        self.heap_arena.?.deinit();
    }
    if (self.heap != null) {
        _ = self.heap.?.deinit();
    }
    if (self.stack != null) {
        self.stack.?.reset();
    }
    if (self.threaded != null) {
        self.threaded.?.deinit();
    }
}

pub fn as(buffer: []u8) Memory {
    return aStack(buffer, false);
}

pub fn ass(buffer: []u8) Memory {
    return aStack(buffer, true);
}
fn aStack(buffer: []u8, single_thread: bool) Memory {
    return Memory{
        .stack = Stack.init(buffer),
        .single_thread = single_thread,
        .is_stack = true,
    };
}

pub fn rs(self: *Memory) void {
    self.stack.?.reset();
}

pub fn isSingleThread(self: Memory) bool {
    return self.single_thread;
}
pub fn isStack(self: Memory) bool {
    return self.is_stack;
}

pub fn allocator(self: *Memory) Allocator {
    if (self.stack != null) {
        if (self.single_thread) {
            return self.stack.?.allocator();
        } else {
            return self.stack.?.threadSafeAllocator();
        }
    } else if (self.stack_heap != null) {
        return self.stack_heap.?.get();
    } else if (self.heap_arena != null) {
        return self.heap_arena.?.allocator();
    } else {
        return self.heap.?.allocator();
    }
}

pub fn alloc(self: *Memory, comptime T: type) !*T {
    return try self.allocator().create(T);
}

pub fn free(self: *Memory, ptr: anytype) void {
    self.allocator().destroy(ptr);
}

pub fn alloc2(self: *Memory, comptime T: type, n: usize) ![]T {
    return try self.allocator().alloc(T, n);
}

pub fn free2(self: *Memory, array: anytype) void {
    self.allocator().free(array);
}

pub fn io(self: *Memory) Io.StdIo {
    if (self.threaded == null) {
        self.threaded = .init(self.allocator(), .{});
    }
    return self.threaded.?.io();
}

pub fn copy(dest: anytype, source: anytype) void {
    @memcpy(dest, source);
}
pub fn copyRange(dest: anytype, source: anytype, from: u32, to: u32) void {
    if (to >= source.len) {
        @memcpy(dest, source[from..]);
    } else {
        @memcpy(dest, source[from..to]);
    }
}

pub fn fill(array: anytype, value: anytype) void {
    var index: u32 = 0;
    while (index < array.len) {
        array[index] = value;
        index += 1;
    }
}
pub fn ptrFromInt(address: usize, T: type) T {
    return @as(T, @ptrFromInt(address));
}
pub fn intFromPtr(ptr: anytype) usize {
    return @intFromPtr(ptr);
}
pub fn sortAsc(comptime T: type, items: []T) void {
    std.mem.sort(T, items, {}, std.sort.asc(T));
}
pub fn sortDesc(comptime T: type, items: []T) void {
    std.mem.sort(T, items, {}, std.sort.desc(T));
}

const Memory = @This();
