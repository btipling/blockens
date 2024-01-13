const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const gl = @import("zopengl");
const cfg = @import("../game/config.zig");

fn initWindow(gl_major: u8, gl_minor: u8) !*glfw.Window {
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);
    glfw.windowHintTyped(.resizable, false);
    glfw.windowHintTyped(.maximized, true);
    glfw.windowHintTyped(.decorated, false);
    const window = glfw.Window.create(cfg.windows_width, cfg.windows_height, cfg.game_name, null) catch |err| {
        std.log.err("Failed to create game window.", .{});
        return err;
    };
    window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);
    return window;
}

fn initGL(gl_major: u8, gl_minor: u8, window: *glfw.Window) !void {
    try gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    {
        const dimensions: [2]i32 = window.getSize();
        const w = dimensions[0];
        const h = dimensions[1];
        std.debug.print("Window size is {d}x{d}\n", .{ w, h });
    }
    gl.enable(gl.BLEND); // enable transparency
    gl.enable(gl.DEPTH_TEST); // enable depth testing
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    // culling
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
}

pub const App = struct {
    allocator: std.mem.Allocator,
    sqliteAlloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, sqliteAlloc: std.mem.Allocator) !App {
        return .{
            .allocator = allocator,
            .sqliteAlloc = sqliteAlloc,
        };
    }

    pub fn deinit(self: *App) void {
        _ = self;
        std.debug.print("\nGoodbye btzig-blockens!\n", .{});
    }

    pub fn run(self: *App) !void {
        // TODO: move alot of this into init and create a separate render loop in a thread
        // as in https://github.com/btipling/3d-zig-game/blob/master/src/main.zig (forked from AlxHnr)
        std.debug.print("\nHello btzig-blockens!\n", .{});
        glfw.init() catch {
            std.log.err("Failed to initialize GLFW library.", .{});
            return;
        };
        defer glfw.terminate();

        const gl_major = 4;
        const gl_minor = 6;

        const window = try initWindow(gl_major, gl_minor);
        defer window.destroy();

        try initGL(gl_major, gl_minor, window);

        zgui.init(self.allocator);
        defer zgui.deinit();

        zstbi.init(self.allocator);
        defer zstbi.deinit();
        zstbi.setFlipVerticallyOnLoad(false);

        const i = zm.identity();
        std.debug.print("identity ? {e}\n", .{i[0]});

        while (!window.shouldClose()) {
            glfw.pollEvents();

            window.swapBuffers();
        }
    }
};
