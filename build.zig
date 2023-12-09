const std = @import("std");
const zgui = @import("libs/zig-gamedev/libs/zgui/build.zig");
const glfw = @import("libs/zig-gamedev/libs/zglfw/build.zig");
const zopengl = @import("libs/zig-gamedev/libs/zopengl/build.zig");
const zstbi = @import("libs/zig-gamedev/libs/zstbi/build.zig");
const zmath = @import("libs/zig-gamedev/libs/zmath/build.zig");
const zmesh = @import("libs/zig-gamedev/libs/zmesh/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "btzig-blockens",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{ .backend = .glfw_opengl3 },
    });
    const zglf_pkg = glfw.package(b, target, optimize, .{});
    const zopengl_pkg = zopengl.package(b, target, optimize, .{});
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zmesh_pkg = zmesh.package(b, target, optimize, .{});

    zglf_pkg.link(exe);
    zopengl_pkg.link(exe);
    zstbi_pkg.link(exe);
    zmath_pkg.link(exe);
    zgui_pkg.link(exe);
    zmesh_pkg.link(exe);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
