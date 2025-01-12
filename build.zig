const std = @import("std");
const utils = @import("test/utils.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cuda_path = b.option(
        []const u8,
        "CUDA_PATH",
        "locally installed Cuda's path",
    );
    const cuda_folder = try getCudaPath(b, cuda_path);
    const cuda_include_dir = try std.fmt.allocPrint(
        b.allocator,
        "{s}/include",
        .{cuda_folder},
    );

    const cudaz_module = b.addModule("cudaz", .{
        .root_source_file = b.path("src/lib.zig"),
    });
    cudaz_module.addIncludePath(.{ .src_path = .{
        .owner = b,
        .sub_path = cuda_include_dir,
    } });

    inline for (.{
        "lib",
        "lib/x64",
        "lib/Win32",
        "lib/x86_64",
        "lib/x86_64-linux-gnu",
        "lib64",
        "lib64/stubs",
        "targets/x86_64-linux",
        "targets/x86_64-linux/lib",
        "targets/x86_64-linux/lib/stubs",
    }) |libpath| {
        const library_path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{
            cuda_folder,
            libpath,
        });
        cudaz_module.addLibraryPath(.{ .src_path = .{
            .owner = b,
            .sub_path = library_path,
        } });
    }

    tests: {
        const test_file = std.fs.cwd().openFile("build.zig.zon", .{}) catch {
            break :tests;
        };
        defer test_file.close();

        const test_file_contents = try test_file.readToEndAlloc(
            b.allocator,
            std.math.maxInt(usize),
        );
        defer b.allocator.free(test_file_contents);

        // Hack for identifying if the current root is `cudaz` project, if not
        // don't register tests.
        if (std.mem.indexOf(
            u8,
            test_file_contents,
            ".name = \"cudaz\"",
        )) |_| {} else break :tests;

        const test_step = b.step("test", "Run library tests");
        const test_dir = try std.fs.cwd().openDir(
            "test",
            .{ .iterate = true },
        );
        var dir_iterator = try test_dir.walk(b.allocator);
        while (try dir_iterator.next()) |item| {
            if (item.kind == .file) {
                const test_path = try std.fmt.allocPrint(
                    b.allocator,
                    "{s}/{s}",
                    .{ "test", item.path },
                );
                const sub_test = b.addTest(.{
                    .name = item.path,
                    .root_source_file = b.path(test_path),
                    .target = target,
                    .optimize = optimize,
                });
                // Add Module
                sub_test.root_module.addImport("cudaz", cudaz_module);

                // Link libc, CUDA and nvrtc libraries
                sub_test.linkLibC();
                sub_test.linkSystemLibrary("cuda");
                sub_test.linkSystemLibrary("nvrtc");
                sub_test.linkSystemLibrary("curand");
                sub_test.linkSystemLibrary("cudart");
                const run_sub_tests = b.addRunArtifact(sub_test);

                const test_name = try std.fmt.allocPrint(
                    b.allocator,
                    "test-{s}",
                    .{item.path[0 .. item.path.len - 4]},
                );
                const ind_test_step = b.step(test_name, "Individual Test");
                ind_test_step.dependOn(&run_sub_tests.step);
                test_step.dependOn(&run_sub_tests.step);
            }
        }
    }
}

fn getCudaPath(b: *std.Build, path: ?[]const u8) ![]const u8 {
    // Return the `cuda_parent` folder if it contains the `include/cuda.h` file.
    return inclpath: {
        if (path) |parent| {
            const cuda_file = try std.fmt.allocPrint(
                b.allocator,
                "{s}/include/cuda.h",
                .{parent},
            );
            defer b.allocator.free(cuda_file);

            _ = std.fs.openFileAbsolute(cuda_file, .{}) catch |err| {
                switch (err) {
                    std.fs.File.OpenError.FileNotFound => {
                        return error.CudaInstallationNotFound;
                    },
                    else => return err,
                }
            };
            break :inclpath try b.allocator.dupe(u8, parent);
        } else {
            // If no specific path is provided, search in probable CUDA roots
            const probable_roots = try getProbableCudaRoots(b);
            defer {
                for (probable_roots) |root| {
                    b.allocator.free(root);
                }
                b.allocator.free(probable_roots);
            }

            for (probable_roots) |parent| {
                const cuda_file = try std.fmt.allocPrint(
                    b.allocator,
                    "{s}/include/cuda.h",
                    .{parent},
                );
                defer b.allocator.free(cuda_file);

                _ = std.fs.openFileAbsolute(cuda_file, .{}) catch continue;
                break :inclpath try b.allocator.dupe(u8, parent);
            }

            return error.CudaInstallationNotFound;
        }
    };
}

fn getProbableCudaRoots(b: *std.Build) ![][]const u8 {
    const cuda_version = cuver: {
        if (b.option(
            []const u8,
            "cuda-version",
            "CUDA version that would be looked for",
        )) |cuver| {
            break :cuver cuver;
        } else {
            break :cuver "";
        }
    };
    const base_paths = [_][]const u8{
        "/usr/local/cuda",
        "/opt/cuda",
        "/usr/lib/cuda",
        "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/",
    };

    var probable_roots = try b.allocator.alloc([]u8, base_paths.len);
    errdefer b.allocator.free(probable_roots);
    for (base_paths, 0..) |path, i| {
        if (cuda_version.len > 0) {
            probable_roots[i] = try std.fmt.allocPrint(
                b.allocator,
                "{s}-{s}",
                .{ path, cuda_version },
            );
        } else {
            probable_roots[i] = try b.allocator.dupe(u8, path);
        }
    }

    return probable_roots;
}
