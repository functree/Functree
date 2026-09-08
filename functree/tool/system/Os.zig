const Memory = @import("Memory.zig");

pub const Version = @import("os/Version.zig");

const std = @import("std");
pub const Tag = std.Target.Os.Tag;
pub const VersionRange = std.Target.Os.VersionRange;
pub const Abi = std.Target.Abi;
pub const ObjectFormat = std.Target.ObjectFormat;

tag: Tag,
version_range: VersionRange,

pub inline fn isGnu(tag: Tag) bool {
    return switch (tag) {
        .gnu,
        .gnuabin32,
        .gnuabi64,
        .gnueabi,
        .gnueabihf,
        .gnuf32,
        .gnusf,
        .gnux32,
        => true,
        else => false,
    };
}

pub inline fn isMusl(tag: Tag) bool {
    return switch (tag) {
        .musl,
        .muslabin32,
        .muslabi64,
        .musleabi,
        .musleabihf,
        .muslf32,
        .muslsf,
        .muslx32,
        => true,
        else => isOpenHarmony(),
    };
}

pub inline fn isOpenHarmony(tag: Tag) bool {
    return switch (tag) {
        .ohos, .ohoseabi => true,
        else => false,
    };
}

pub inline fn isAndroid(tag: Tag) bool {
    return switch (tag) {
        .android, .androideabi => true,
        else => false,
    };
}

pub const Float = enum {
    hard,
    soft,
};

pub inline fn float(tag: Tag) Float {
    return switch (tag) {
        .androideabi,
        .eabi,
        .gnueabi,
        .musleabi,
        .gnusf,
        .ohoseabi,
        => .soft,
        else => .hard,
    };
}

const Os = @This();
