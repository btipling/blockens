const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const cfg = @import("config.zig");
const ui = @import("ui/ui.zig");
const cube = @import("./shape/cube.zig");
const plane = @import("./shape/plane.zig");
const cursor = @import("./shape/cursor.zig");
const screen = @import("./screen/screen.zig");
const oldState = @import("state/state.zig");
const gameState = @import("state/game.zig");
const chunk = @import("chunk.zig");
const math = @import("./math/math.zig");
const blecs = @import("blecs/blecs.zig");

const pressStart2PFont = @embedFile("assets/fonts/PressStart2P/PressStart2P-Regular.ttf");
const robotoMonoFont = @embedFile("assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");

fn cursorPosCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    state.input.last_x = xpos;
    state.input.last_y = ypos;
}

fn glErrorCallbackfn(
    source: gl.Enum,
    errorType: gl.Enum,
    id: gl.Uint,
    severity: gl.Enum,
    _: gl.Sizei,
    message: [*c]const gl.Char,
    _: *const anyopaque,
) callconv(.C) void {
    const errorMessage: [:0]const u8 = std.mem.sliceTo(message, 0);
    std.debug.print("\n:::GL Error:::\n", .{});
    std.debug.print("\n\t - source: {d}\n", .{source});
    std.debug.print("\n\t - type: {d}\n", .{errorType});
    std.debug.print("\n\t - id: {d}\n", .{id});
    std.debug.print("\n\t - severity: {d}\n", .{severity});
    std.debug.print("\n\t - message: `{s}`\n", .{errorMessage});
    @panic("\nExiting due to OpenGL Error\n");
}
// from https://registry.khronos.org/OpenGL/api/GL/glext.h
const GL_DEBUG_OUTPUT_SYNCHRONOUS = 0x8242;
const GL_DEBUG_OUTPUT = 0x92E0;

pub var state: *gameState.Game = undefined;

fn initWindow(gl_major: u8, gl_minor: u8) !*glfw.Window {
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);
    glfw.windowHintTyped(.resizable, false);
    glfw.windowHintTyped(.focused, true);
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
    gl.enable(gl.DEPTH_TEST);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    // culling
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.debugMessageCallback(glErrorCallbackfn, null);
    gl.enable(GL_DEBUG_OUTPUT);
    gl.enable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
}

pub const Game = struct {
    pub fn init(allocator: std.mem.Allocator) !Game {
        // TODO: Move more of run into init and create a separate render loop in a thread
        // as in https://github.com/btipling/3d-zig-game/blob/master/src/main.zig (forked from AlxHnr)
        glfw.init() catch @panic("Unable to init glfw");

        const gl_major = 4;
        const gl_minor = 6;

        const window = try initWindow(gl_major, gl_minor);

        try initGL(gl_major, gl_minor, window);

        _ = window.setCursorPosCallback(cursorPosCallback);

        zgui.init(allocator);
        const glsl_version: [*c]const u8 = "#version 130";
        zgui.backend.initWithGlSlVersion(window, glsl_version);
        zmesh.init(allocator);
        zstbi.init(allocator);
        zstbi.setFlipVerticallyOnLoad(false);
        const gameFont = zgui.io.addFontFromMemory(pressStart2PFont, std.math.floor(24.0 * 1.1));
        const codeFont = zgui.io.addFontFromMemory(robotoMonoFont, std.math.floor(40.0 * 1.1));
        zgui.io.setDefaultFont(gameFont);

        state = try allocator.create(gameState.Game);
        state.* = .{
            .allocator = allocator,
            .ui = gameState.UI{
                .codeFont = codeFont,
                .gameFont = gameFont,
            },
            .window = window,
        };

        blecs.init();

        return .{};
    }

    pub fn deinit(_: Game) void {
        _ = blecs.ecs.fini(state.world);
        zstbi.deinit();
        zmesh.deinit();
        zgui.backend.deinit();
        zgui.deinit();
        state.window.destroy();
        glfw.terminate();
        state.allocator.destroy(state);
        std.debug.print("\nGoodbye blockens!\n", .{});
    }

    pub fn run(_: Game) !void {
        std.debug.print("\nHello blockens!\n", .{});
        main_loop: while (!state.window.shouldClose()) {
            glfw.pollEvents();

            if (state.quit) {
                break :main_loop;
            }

            {
                const fb_size = state.window.getFramebufferSize();
                const w: u32 = @intCast(fb_size[0]);
                const h: u32 = @intCast(fb_size[1]);
                zgui.backend.newFrame(w, h);
            }
            _ = blecs.ecs.progress(state.world, 0);
            zgui.backend.draw();
            state.window.swapBuffers();
        }
    }
};
