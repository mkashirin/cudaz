<h1 align="center">CUDA library for Zig</h1>

<p align="center"><b>Works with latest zig v0.13.0.</b></p>

This library helps to interact with NVIDIA GPUs from Zig. Provides high level
interface to communicate with GPU. It can detect CUDA installation and link it
to a project's binary on Linux/MacOS. Check
[customization](https://github.com/akhildevelops/cudaz/tree/main#Customization)
to give CUDA manual path.

## Features

- Memory Allocation in GPU with defined size
- Copying data from host to GPU and viceversa
- Compiling (`.cu`) and loading kernels (`.ptx`) both from file and text
- Running kernels with grid/blocks/threads configuration
- [Generate random numbers](test/rng.zig)

Check [test.zig](./test.zig) file for code samples.

## Installation

Download and save the library path in `build.zig.zon` file by running:
```shell
zig fetch --save https://github.com/mkashirin/cudaz/tarball/master
```
Add Cudaz module in your project's `build.zig` file that will link to your
project's binary.
```zig
// build.zig

const std = @import("std");

pub fn build(b: *std.Build) !void {
    // exe points to main.zig that uses cudaz
    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.host,
    });

    // Point to cudaz dependency
    const cudaz_dep = b.dependency("cudaz", .{});

    // Fetch and add the module from cudaz dependency
    const cudaz_module = cudaz_dep.module("cudaz");
    exe.root_module.addImport("cudaz", cudaz_module);

    // Dynamically link to libc, cuda, nvrtc
    exe.linkLibC();
    exe.linkSystemLibrary("cuda");
    exe.linkSystemLibrary("nvrtc");

    // Run binary
    const run = b.step("run", "Run the binary");
    const run_step = b.addRunArtifact(exe);
    run.dependOn(&run_step.step);
}
```

## Quick Start

To run the code below, refer to the example project:
[increment](./example/increment).

```zig
// src/main.zig

const std = @import("std");
const Cuda = @import("cudaz");
const CuDevice = Cuda.Device;
const CuCompile = Cuda.Compile;
const CuLaunchConfig = Cuda.LaunchConfig;

// CUDA Kernel
const increment_kernel =
    \\extern "C" __global__ void increment(float *out)
    \\{
    \\    int i = blockIdx.x * blockDim.x + threadIdx.x;
    \\    out[i] = out[i] + 1;
    \\}
;

pub fn main() !void {
    // Initialize allocator.
    var gp = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gp.deinit();
    const allocator = gp.allocator();

    // Initialize GPU.
    const device = try CuDevice.default();
    defer device.free();

    // Copy data from host to GPU.
    const data = [_]f32{ 1.2, 2.8, 0.123 };
    const cu_slice = try device.htodCopy(f32, &data);
    defer cu_slice.free();

    // Compile and load the Kernel.
    const ptx = try CuCompile.cudaText(increment_kernel, .{}, allocator);
    defer allocator.free(ptx);
    const module = try CuDevice.loadPtxText(ptx);
    const function = try module.getFunc("increment");

    // Run the kernel on the data.
    try function.run(.{&cu_slice.device_ptr}, CuLaunchConfig{
        .block_dim = .{ 3, 1, 1 },
        .grid_dim = .{ 1, 1, 1 },
        .shared_mem_bytes = 0,
    });

    // Retrieve incremented data back to the system.
    const incremented_arr = try CuDevice.syncReclaim(
        f32,
        allocator,
        cu_slice,
    );
    defer incremented_arr.deinit();
}
```

Examples:
- [Incrementing Array on GPU](examples/increment/)
- [Sending Custom Types to GPU](examples/custom_type/)

## Customization
- It is intelligent to identify and link to installed cuda libraries. If
needed, provide cuda installation path manually by mentioning build parameter
```shell
zig build -DCUDA_PATH=<cuda_folder>
```

Inspired by
[Rust Cuda Library](https://github.com/coreylowman/cudarc/tree/main).
