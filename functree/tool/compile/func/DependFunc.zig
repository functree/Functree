depend_type: DependType,
full_name: []const u8,
func_path: []const u8,
import_path: []const u8,

pub fn a(depend_type: DependType, full_name: []const u8, func_path: []const u8, import_path: []const u8) DependFunc {
    const self = DependFunc{
        .depend_type = depend_type,
        .full_name = full_name,
        .func_path = func_path,
        .import_path = import_path,
    };
    return self;
}
pub fn d(self: DependFunc) void {
    _ = self;
}

pub const DependType = enum {
    func_source,
    elf_bin,
    coff_bin,
};

const DependFunc = @This();
