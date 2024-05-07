const std = @import("std");
const lua = @import("libs/lua/build.zig");
const sqlite = @import("libs/sqlite/build.zig");

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

    // options
    const options = b.addOptions();
    const use_tracy = b.option(bool, "use_tracy", "enable profiling tracy") orelse false;
    if (use_tracy) {
        const ztracy = b.dependency("ztracy", .{
            .enable_ztracy = true,
            .enable_fibers = true,
        });
        exe.root_module.addImport("ztracy", ztracy.module("root"));
        exe.linkLibrary(ztracy.artifact("tracy"));
    }
    options.addOption(bool, "use_tracy", use_tracy);
    exe.root_module.addOptions("config", options);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const zmesh = b.dependency("zmesh", .{});
    exe.root_module.addImport("zmesh", zmesh.module("root"));
    exe.linkLibrary(zmesh.artifact("zmesh"));

    const zglfw = b.dependency("zglfw", .{});
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    const zgui = b.dependency("zgui", .{
        .shared = false,
        .with_implot = true,
        .backend = .glfw_opengl3,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));

    const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));

    const zjobs = b.dependency("zjobs", .{});
    exe.root_module.addImport("zjobs", zjobs.module("root"));

    const zflecs = b.dependency("zflecs", .{});
    exe.root_module.addImport("zflecs", zflecs.module("root"));
    exe.linkLibrary(zflecs.artifact("flecs"));

    const zstbi = b.dependency("zstbi", .{});
    exe.root_module.addImport("zstbi", zstbi.module("root"));
    exe.linkLibrary(zstbi.artifact("zstbi"));

    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

    const znoise = b.dependency("znoise", .{});
    exe.root_module.addImport("znoise", znoise.module("root"));
    exe.linkLibrary(znoise.artifact("FastNoiseLite"));

    @import("system_sdk").addLibraryPathsTo(exe);

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

    const run_step = b.step("run", "Run blockens");
    run_step.dependOn(&run_cmd.step);
}
