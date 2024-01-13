const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
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

        zgui.init(self.allocator);
        defer zgui.deinit();

        while (!window.shouldClose()) {
            glfw.pollEvents();

            window.swapBuffers();
        }
    }
};
