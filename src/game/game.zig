fn framebufferSizeCallback(_: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    std.debug.print("frame buffer resized {d} {d}", .{ width, height });
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
    // Ignored errors:
    switch (id) {
        131185 => return, // GL_STATIC_DRAW hint
        131218 => return, // fragment shader recompiled
        else => {},
    }
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

pub var state: *game_state.Game = undefined;
var window_width: u32 = 0;
var window_height: u32 = 0;

fn initWindow(gl_major: u8, gl_minor: u8) !*glfw.Window {
    const m = glfw.Monitor.getPrimary() orelse @panic("no primary monitor");
    const vm = try m.getVideoMode();
    var fullscreen_monitor: ?*glfw.Monitor = null;
    const mode: glfw.VideoMode = vm.*;
    state.ui.display_settings_width = @intCast(mode.width);
    state.ui.display_settings_height = @intCast(mode.height);
    load_display_settings: {
        var display_settings: data.display_settings = .{};
        state.db.loadDisplaySettings(&display_settings) catch |load_err| {
            switch (load_err) {
                data.DataErr.NotFound => {
                    state.db.saveDisplaySettings(
                        false,
                        true,
                        false,
                        state.ui.display_settings_width,
                        state.ui.display_settings_height,
                    ) catch |save_err| return save_err;
                    break :load_display_settings;
                },
                else => return load_err,
            }
        };
        if (display_settings.fullscreen) fullscreen_monitor = m;
        state.ui.display_settings_fullscreen = display_settings.fullscreen;
        state.ui.display_settings_maximized = display_settings.maximized;
        state.ui.display_settings_decorated = display_settings.decorated;
        state.ui.display_settings_width = display_settings.width;
        state.ui.display_settings_height = display_settings.height;
    }

    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, false);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);
    glfw.windowHintTyped(.resizable, false);
    glfw.windowHintTyped(.maximized, state.ui.display_settings_maximized);
    glfw.windowHintTyped(.decorated, state.ui.display_settings_decorated);
    const window = glfw.Window.create(
        @intCast(state.ui.display_settings_width),
        @intCast(state.ui.display_settings_height),
        cfg.game_name,
        fullscreen_monitor,
    ) catch |err| {
        std.log.err("Failed to create game window.", .{});
        return err;
    };
    _ = window.setFramebufferSizeCallback(framebufferSizeCallback);
    window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
    glfw.makeContextCurrent(window);
    glfw.swapInterval(0);

    return window;
}

fn initGL(gl_major: u8, gl_minor: u8, _: *glfw.Window) !void {
    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

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
        state = try allocator.create(game_state.Game);
        errdefer allocator.destroy(state);
        state.* = .{
            .allocator = allocator,
        };

        var db = try data.Data.init(allocator);
        errdefer db.deinit();
        db.ensureSchema() catch |err| {
            std.log.err("Failed to ensure schema: {}\n", .{err});
            return err;
        };
        state.db = db;

        zgui.init(allocator);
        errdefer zgui.deinit();

        ui.init(allocator);
        errdefer ui.deinit();
        state.ui = ui.ui;

        glfw.init() catch @panic("Unable to init glfw");

        const gl_major = 4;
        const gl_minor = 6;

        const window = try initWindow(gl_major, gl_minor);
        state.ui.setScreenSize(window);
        state.window = window;

        try initGL(gl_major, gl_minor, window);

        _ = window.setCursorPosCallback(input.cursor.cursorPosCallback);
        _ = window.setMouseButtonCallback(input.mouse_button.mouseBtnCallback);

        const glsl_version: [:0]const u8 = "#version 450";
        zgui.backend.initWithGlSlVersion(window, glsl_version);
        zmesh.init(allocator);
        errdefer zmesh.deinit();
        zstbi.init(allocator);
        errdefer zstbi.deinit();
        zstbi.setFlipVerticallyOnLoad(false);

        try state.initInternals();
        errdefer state.deinit();

        blecs.init();
        errdefer blecs.ecs.fini(state.world);
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
            if (config.use_tracy) {
                const render_frame_zone = ztracy.ZoneNC(@src(), "RenderFrame", 0x00_00_00_ff);
                defer render_frame_zone.End();
                glfw.pollEvents();
                {
                    const frame: f32 = @floatCast(glfw.getTime());
                    state.input.delta_time = frame - state.input.lastframe;
                    state.input.lastframe = frame;
                }
                if (state.quit) {
                    break :main_loop;
                }
                {
                    gl.viewport(0, 0, @intFromFloat(state.ui.screen_size[0]), @intFromFloat(state.ui.screen_size[1]));
                }
                {
                    const imgui_new_frame_zone = ztracy.ZoneN(@src(), "ImguiNewFrame");
                    defer imgui_new_frame_zone.End();
                    const fb_size = state.window.getFramebufferSize();
                    const w: u32 = @intCast(fb_size[0]);
                    const h: u32 = @intCast(fb_size[1]);
                    zgui.backend.newFrame(w, h);
                }
                {
                    const handle_i_zone = ztracy.ZoneN(@src(), "ThreadHandler");
                    defer handle_i_zone.End();
                    try thread.handler.handle_incoming();
                }
                {
                    const ecs_progress_zone = ztracy.ZoneN(@src(), "ECSProgress");
                    defer ecs_progress_zone.End();
                    _ = blecs.ecs.progress(state.world, state.input.delta_time);
                }
                {
                    const imgui_draw_zone = ztracy.ZoneN(@src(), "ImguiDraw");
                    defer imgui_draw_zone.End();
                    zgui.backend.draw();
                }
                {
                    const swap_buffers_zone = ztracy.ZoneN(@src(), "SwapBuffers");
                    defer swap_buffers_zone.End();
                    state.window.swapBuffers();
                }
                ztracy.FrameMark();
            } else {
                glfw.pollEvents();
                {
                    const frame: f32 = @floatCast(glfw.getTime());
                    state.input.delta_time = frame - state.input.lastframe;
                    state.input.lastframe = frame;
                }
                if (state.quit) {
                    break :main_loop;
                }
                {
                    gl.viewport(0, 0, @intFromFloat(state.ui.screen_size[0]), @intFromFloat(state.ui.screen_size[1]));
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
            }
        }
    }
};

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
const data = @import("data/data.zig");
const game_state = @import("state.zig");
const blecs = @import("blecs/blecs.zig");
const input = @import("input/input.zig");
const thread = @import("thread/thread.zig");
const ui = @import("ui/ui.zig");
