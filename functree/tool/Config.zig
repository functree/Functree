const StaticStringMap = @import("system/datatype/StaticStringMap.zig");
const System = @import("System.zig");
const Os = System.Os;
const Cpu = System.Cpu;

pub const version: []const u8 = "0.16.0";

pub const output_tmp_dir_path: []const u8 = ".funcfile";
pub const reserve_target_code_file: bool = true;
pub const reserve_token_file: bool = false;
pub const reserve_code_node_file: bool = false;

pub var main_source_file_path: []const u8 = undefined;
pub var output_type: OutPutType = .run;
pub var output_tmp_dir_absolute_path: []const u8 = undefined;
pub var extra_cmd_args: []const []const u8 = undefined;

pub const single_thread: bool = false;
pub const is_test = System.isTest();
pub const abi: Os.Abi = System.getAbi();
pub const cpu = System.getCpu();
pub const os: Os = System.getOs();
pub const object_format: Os.ObjectFormat = System.getObjectFormat(os.tag, cpu.arch);
pub const target_system: System = .{
    .cpu = cpu,
    .os = os,
    .abi = abi,
    .ofmt = object_format,
};

pub const OutPutType = enum {
    build_exe,
    build_lib,
    build_obj,
    _test,
    run,
    version,
    help,
};
pub const OutPutTypeMap = StaticStringMap.t(OutPutType).a(.{
    .{ "build-exe", .build_exe },
    .{ "build-lib", .build_lib },
    .{ "build-obj", .build_obj },
    .{ "test", ._test },
    .{ "run", .run },
    .{ "version", .version },
    .{ "help", .help },
});

const Config = @This();
