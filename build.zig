const std = @import("std");
const ui = @import("libs/ui/build.zig");
const glfw = @import("libs/glfw/build.zig");
const opengl = @import("libs/opengl/build.zig");
const stbi = @import("libs/stbi/build.zig");
const math = @import("libs/math/build.zig");
const mesh = @import("libs/mesh/build.zig");
const flecs = @import("libs/flecs/build.zig");
const lua = @import("libs/lua/build.zig");
const sqlite = @import("libs/sqlite/build.zig");
const zmpl = @import("libs/zmpl/build.zig");

pub const path = getPath();

inline fn getPath() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "blockens",
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
    const mesh_pkg = mesh.package(b, target, optimize, .{});
    const flecs_pkg = flecs.package(b, target, optimize, .{});

    glfw_pkg.link(exe);
    opengl_pkg.link(exe);
    stbi_pkg.link(exe);
    math_pkg.link(exe);
    ui_pkg.link(exe);
    mesh_pkg.link(exe);
    flecs_pkg.link(exe);

    const lua_module = lua.buildLibrary(
        b,
        target,
        optimize,
        .{
            .options = .{ .lua_version = .lua54, .shared = false },
        },
    );
    exe.root_module.addImport("ziglua", lua_module);

    const sqlite_module = sqlite.buildLibrary(
        b,
        target,
        optimize,
        .{},
    );
    exe.root_module.addImport("sqlite", sqlite_module);

    const shader_template_path = try std.fs.path.join(
        b.allocator,
        &[_][]const u8{ "src", "game", "shaders", "templates" },
    );
    const zmpl_module = try zmpl.buildLibrary(
        b,
        target,
        optimize,
        .{ .options = .{
            .template_path = shader_template_path,
        } },
    );
    exe.root_module.addImport("zmpl", zmpl_module);

    const run_step = b.step("run", "Run blockens");
    run_step.dependOn(&run_cmd.step);
}
