const std = @import("std");
const ui = @import("libs/ui/build.zig");
const glfw = @import("libs/glfw/build.zig");
const opengl = @import("libs/opengl/build.zig");
const stbi = @import("libs/stbi/build.zig");
const math = @import("libs/math/build.zig");
// const zmesh = @import("libs/zig-gamedev/libs/zmesh/build.zig");

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

    const glfw_pkg = glfw.package(b, target, optimize, .{});
    const ui_pkg = ui.package(b, target, optimize, .{
        .options = .{ .backend = .glfw_opengl3 },
    });
    const opengl_pkg = opengl.package(b, target, optimize, .{});
    const stbi_pkg = stbi.package(b, target, optimize, .{});
    const math_pkg = math.package(b, target, optimize, .{});
    // const zmesh_pkg = zmesh.package(b, target, optimize, .{});

    glfw_pkg.link(exe);
    opengl_pkg.link(exe);
    stbi_pkg.link(exe);
    math_pkg.link(exe);
    ui_pkg.link(exe);
    // zmesh_pkg.link(exe);

    // const ziglua = b.dependency("ziglua", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .version = .lua_54,
    // });
    // exe.addModule("ziglua", ziglua.module("ziglua"));
    // exe.linkLibrary(ziglua.artifact("lua"));

    // const sqlite = b.dependency("sqlite", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // exe.addModule("sqlite", sqlite.module("sqlite"));

    // // links the bundled sqlite3, so leave this out if you link the system one
    // exe.linkLibrary(sqlite.artifact("sqlite"));

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
