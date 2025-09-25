const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const snappy_version = std.SemanticVersion.parse("1.2.2") catch unreachable;

    const upstream = b.dependency("snappy", .{});

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "snappy",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    lib.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = &[_][]const u8{
            "snappy-sinksource.cc",
            "snappy-stubs-internal.cc",
            "snappy.cc",
            "snappy-c.cc",
        },
        .flags = &[_][]const u8{
            "-std=c++11",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-Wno-sign-compare",
        },
    });
    const snappy_stubs_public_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("snappy-stubs-public.h.in") },
    }, .{
        .HAVE_SYS_UIO_H_01 = target.result.os.tag != .windows,
        .PROJECT_VERSION_MAJOR = @as(i64, @intCast(snappy_version.major)),
        .PROJECT_VERSION_MINOR = @as(i64, @intCast(snappy_version.minor)),
        .PROJECT_VERSION_PATCH = @as(i64, @intCast(snappy_version.patch)),
    });

    lib.addIncludePath(upstream.path("."));
    lib.addConfigHeader(snappy_stubs_public_h);

    const install_lib = b.addInstallArtifact(lib, .{});
    install_lib.artifact.installHeader(upstream.path("snappy.h"), "snappy.h");
    install_lib.artifact.installHeader(upstream.path("snappy-c.h"), "snappy-c.h");
    install_lib.artifact.installHeader(snappy_stubs_public_h.getOutput(), "snappy-stubs-public.h");
    b.getInstallStep().dependOn(&install_lib.step);

    const module = b.addModule("snappy", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.linkLibrary(lib);
    module.addIncludePath(upstream.path("."));

    const test_snappy = b.addTest(.{
        .name = "snappy",
        .root_module = module,
        .filters = &[_][]const u8{},
    });

    const run_test_snappy = b.addRunArtifact(test_snappy);
    const tls_run_test_snappy = b.step("test", "Run the snappy test");
    tls_run_test_snappy.dependOn(&run_test_snappy.step);
}
