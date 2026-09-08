pub const Console = @import("io/Console.zig");
// pub const Net = @import("io/Net.zig");

const std = @import("std");
pub const Uri = std.Uri;

pub const Reader = std.Io.Reader;
pub const Writer = std.Io.Writer;

pub const StdIo = std.Io;
pub const Event = std.Io.Event;
pub const Mutex = std.Io.Mutex;

const Io = @This();
