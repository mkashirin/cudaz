pub usingnamespace {
    @cImport({
        @cInclude("cuda.h");
        @cInclude("nvrtc.h");
    });
    @import("curand.zig");
    struct {
        pub extern fn cudaMalloc(devptr: [*c]?*anyopaque, size: usize) c_uint;
    };
};
