const System = @import("../System.zig");
const Memory = System.Memory;
const DataType = System.DataType;
const List = DataType.List;

const Func = @import("Func.zig");
const TargetCode = @import("gen/TargetCode.zig");
const GenZigCode = @import("gen/GenZigCode.zig");

pub fn genTargetCodeList(memory: *Memory, _func: Func) !List.t(TargetCode) {
    var gen = GenZigCode.a(memory, _func);
    defer gen.d();
    return try gen.genTargetCodeList();
}

pub const GenError = error{
    invalid_code_type,
    open_include_file_fail,
    out_of_memory,
};
pub fn getErrorText(err: GenError) []const u8 {
    switch (err) {
        GenError.invalid_code_type => return "invalid_code_type",
        GenError.open_include_file_fail => return "open_include_file_fail",
        GenError.out_of_memory => return "out_of_memory",
    }
}

const Gen = @This();
