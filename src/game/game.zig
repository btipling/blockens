const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const ztracy = @import("ztracy");
const zopengl = @import("zopengl");
const config = @import("config");
const gl = zopengl.bindings;
const zstbi = @import("zstbi");
const zmesh = @import("zmesh");
const cfg = @import("config.zig");
const gameState = @import("state.zig");
const blecs = @import("blecs/blecs.zig");
const input = @import("input/input.zig");
const thread = @import("thread/thread.zig");

const pressStart2PFont = @embedFile("assets/fonts/PressStart2P/PressStart2P-Regular.ttf");
const robotoMonoFont = @embedFile("assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");

fn cursorPosCallback(_: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    input.cursor.cursorPosCallback(xpos, ypos);
}

const glError = struct {
    source: gl.Enum = 0,
    error_type: gl.Enum = 0,
    id: u32 = 0,
    severity: gl.Enum = 0,
    fn equal(a: glError, b: glError) bool {
        if (a.source != b.source) return false;
        if (a.error_type != b.error_type) return false;
        if (a.id != b.id) return false;
        if (a.severity != b.severity) return false;
        return true;
    }
};

var prev_error: glError = .{};

fn glErrorCallbackfn(
    source: gl.Enum,
    error_type: gl.Enum,
    id: u32,
    severity: gl.Enum,
    _: gl.Sizei,
    message: [*c]const gl.Char,
    _: *const anyopaque,
) callconv(.C) void {
    const err: glError = .{
        .source = source,
        .error_type = error_type,
        .id = id,
        .severity = severity,
    };
    if (prev_error.equal(err)) return;
    prev_error = err;
    const errorMessage: [:0]const u8 = std.mem.sliceTo(message, 0);
    std.debug.print("\n:::GL Error:::\n", .{});
    std.debug.print("\n\t - source: {d}\n", .{source});
    std.debug.print("\n\t - type: {d}\n", .{error_type});
    std.debug.print("\n\t - id: {d}\n", .{id});
    std.debug.print("\n\t - severity: {d}\n", .{severity});
    std.debug.print("\n\t - message: `{s}`\n", .{errorMessage});
    switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => @panic("\nExiting due to HIGH OpenGL Error\n"),
        gl.DEBUG_SEVERITY_MEDIUM => std.debug.print("medium severity error\n", .{}),
        gl.DEBUG_SEVERITY_LOW => std.debug.print("low severity error\n", .{}),
        gl.DEBUG_SEVERITY_NOTIFICATION => std.debug.print("notification error\n", .{}),
        else => std.debug.print("unknown error", .{}),
    }
}
// from https://registry.khronos.org/OpenGL/api/GL/glext.h
const GL_DEBUG_OUTPUT_SYNCHRONOUS = 0x8242;
const GL_DEBUG_OUTPUT = 0x92E0;

pub var state: *gameState.Game = undefined;

fn initWindow(gl_major: u8, gl_minor: u8) !*glfw.Window {
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, false);
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
    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

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
    const gl_version = gl.getString(gl.VERSION);
    const gl_renderer = gl.getString(gl.RENDERER);
    std.debug.print("system gl version: {s} renderer: {s}\n", .{ gl_version, gl_renderer });
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
        const glsl_version: [:0]const u8 = "#version 450";
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
        try state.initInternals();

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
        state.deinit();
        state.allocator.destroy(state);
        std.debug.print("\nGoodbye blockens!\n", .{});
    }

    pub fn run(_: Game) !void {
        if (config.use_tracy) {}
        std.debug.print("\nHello blockens!\n", .{});
        main_loop: while (!state.window.shouldClose()) {
            glfw.pollEvents();
            {
                const currentFrame: f32 = @floatCast(glfw.getTime());
                state.input.delta_time = currentFrame - state.input.lastframe;
                state.input.lastframe = currentFrame;
            }
            if (state.quit) {
                break :main_loop;
            }

            {
                const fb_size = state.window.getFramebufferSize();
                const w: u32 = @intCast(fb_size[0]);
                const h: u32 = @intCast(fb_size[1]);
                zgui.backend.newFrame(w, h);
            }
            try thread.handler.handle_incoming();
            _ = blecs.ecs.progress(state.world, state.input.delta_time);
            zgui.backend.draw();
            state.window.swapBuffers();
            if (config.use_tracy) {
                ztracy.FrameMark();
            }
        }
    }
};
