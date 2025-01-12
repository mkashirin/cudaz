pub const packages = struct {
    pub const @"12207c43ae3bfe61f4db18c0e523da96adcae29a6caa1c58c782f6d65510bd1e11fa" = struct {
        pub const build_root = "/home/michael/code/zig/cudaz/examples/increment/../..";
        pub const build_zig = @import("12207c43ae3bfe61f4db18c0e523da96adcae29a6caa1c58c782f6d65510bd1e11fa");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "cudaz", "12207c43ae3bfe61f4db18c0e523da96adcae29a6caa1c58c782f6d65510bd1e11fa" },
};
