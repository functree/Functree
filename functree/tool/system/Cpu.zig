const Memory = @import("Memory.zig");

const std = @import("std");
pub const Arch = std.Target.Cpu.Arch;
pub const Feature = std.Target.Cpu.Feature;

/// Architecture
arch: Arch,

/// An explicit list of the entire CPU feature set. It may differ from the specific CPU model's features.
features: Feature.Set,

pub inline fn isX86(arch: Arch) bool {
    return switch (arch) {
        .x86_16, .x86, .x86_64 => true,
        else => false,
    };
}

/// Note that this includes Thumb.
pub inline fn isArm(arch: Arch) bool {
    return switch (arch) {
        .arm, .armeb => true,
        else => arch.isThumb(),
    };
}

pub inline fn isThumb(arch: Arch) bool {
    return switch (arch) {
        .thumb, .thumbeb => true,
        else => false,
    };
}

pub inline fn isAARCH64(arch: Arch) bool {
    return switch (arch) {
        .aarch64, .aarch64_be => true,
        else => false,
    };
}

pub inline fn isArc(arch: Arch) bool {
    return switch (arch) {
        .arc, .arceb => true,
        else => false,
    };
}

pub inline fn isHppa(arch: Arch) bool {
    return switch (arch) {
        .hppa, .hppa64 => true,
        else => false,
    };
}

pub inline fn isWasm(arch: Arch) bool {
    return switch (arch) {
        .wasm32, .wasm64 => true,
        else => false,
    };
}

pub inline fn isLoongArch(arch: Arch) bool {
    return switch (arch) {
        .loongarch32, .loongarch64 => true,
        else => false,
    };
}

pub inline fn isRISCV(arch: Arch) bool {
    return arch.isRiscv32() or arch.isRiscv64();
}

pub inline fn isRiscv32(arch: Arch) bool {
    return switch (arch) {
        .riscv32, .riscv32be => true,
        else => false,
    };
}

pub inline fn isRiscv64(arch: Arch) bool {
    return switch (arch) {
        .riscv64, .riscv64be => true,
        else => false,
    };
}

pub inline fn isMicroblaze(arch: Arch) bool {
    return switch (arch) {
        .microblaze, .microblazeel => true,
        else => false,
    };
}

pub inline fn isMIPS(arch: Arch) bool {
    return arch.isMIPS32() or arch.isMIPS64();
}

pub inline fn isMIPS32(arch: Arch) bool {
    return switch (arch) {
        .mips, .mipsel => true,
        else => false,
    };
}

pub inline fn isMIPS64(arch: Arch) bool {
    return switch (arch) {
        .mips64, .mips64el => true,
        else => false,
    };
}

pub inline fn isPowerPC(arch: Arch) bool {
    return arch.isPowerPC32() or arch.isPowerPC64();
}

pub inline fn isPowerPC32(arch: Arch) bool {
    return switch (arch) {
        .powerpc, .powerpcle => true,
        else => false,
    };
}

pub inline fn isPowerPC64(arch: Arch) bool {
    return switch (arch) {
        .powerpc64, .powerpc64le => true,
        else => false,
    };
}

pub inline fn isSPARC(arch: Arch) bool {
    return switch (arch) {
        .sparc, .sparc64 => true,
        else => false,
    };
}

pub inline fn isSpirV(arch: Arch) bool {
    return switch (arch) {
        .spirv32, .spirv64 => true,
        else => false,
    };
}

pub inline fn isSh(arch: Arch) bool {
    return switch (arch) {
        .sh, .sheb => true,
        else => false,
    };
}

pub inline fn isBpf(arch: Arch) bool {
    return switch (arch) {
        .bpfel, .bpfeb => true,
        else => false,
    };
}

pub inline fn isNvptx(arch: Arch) bool {
    return switch (arch) {
        .nvptx, .nvptx64 => true,
        else => false,
    };
}

pub inline fn isXtensa(arch: Arch) bool {
    return switch (arch) {
        .xtensa, .xtensaeb => true,
        else => false,
    };
}

const Cpu = @This();
