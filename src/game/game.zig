const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const cfg = @import("config.zig");
const ui = @import("ui/ui.zig");
const controls = @import("controls.zig");
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

var ctrls: *controls.Controls = undefined;

fn cursorPosCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    ctrls.cursorPosCallback(xpos, ypos);
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
    allocator: std.mem.Allocator,
    sqliteAlloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, sqliteAlloc: std.mem.Allocator) !Game {
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

        return .{
            .allocator = allocator,
            .sqliteAlloc = sqliteAlloc,
        };
    }

    pub fn deinit(self: *Game) void {
        _ = blecs.ecs.fini(state.world);
        zstbi.deinit();
        zmesh.deinit();
        zgui.backend.deinit();
        zgui.deinit();
        state.window.destroy();
        glfw.terminate();
        self.allocator.destroy(state);
        std.debug.print("\nGoodbye blockens!\n", .{});
    }

    pub fn run(self: *Game) !void {
        std.debug.print("\nHello blockens!\n", .{});

        var appState = try oldState.State.init(self.allocator, self.sqliteAlloc);
        defer appState.deinit();

        var gameUI = try ui.UI.init(&appState, state.window, self.allocator);
        defer gameUI.deinit();

        // init view imports
        const planePosition = oldState.position.Position{ .x = 0.0, .y = 0.0, .z = -1.0 };
        var worldPlane = try plane.Plane.init("worldplane", planePosition, self.allocator);
        defer worldPlane.deinit();
        var uiCursor = try cursor.Cursor.init("cursor", self.allocator);
        defer uiCursor.deinit();

        // init views
        var gameScreen = try screen.world.World.initWithHUD(
            worldPlane,
            uiCursor,
            &appState.worldScreen,
            &appState.character,
        );
        _ = &gameScreen;
        var demoScreen = try screen.world.World.init(&appState.demoScreen);
        _ = &demoScreen;

        var textureGen = try screen.texture_gen.TextureGenerator.init(&appState, self.allocator);
        defer textureGen.deinit();

        var characterScreen = try screen.character.Character.init(&appState.character);
        defer characterScreen.deinit();

        var c = try controls.Controls.init(state.window, &appState);
        ctrls = &c;

        // uncomment to start in a specific view:
        // try appState.setGameScreen();
        // try appState.setChunkGeneratorScreen();
        // try appState.setWorldEditorScreen();
        try appState.setCharacterDesignerScreen();

        var focusedAt: gl.Float = 0.0;
        main_loop: while (!state.window.shouldClose()) {
            glfw.pollEvents();

            const currentFrame: gl.Float = @as(gl.Float, @floatCast(glfw.getTime()));
            appState.worldScreen.deltaTime = currentFrame - appState.worldScreen.lastFrame;
            appState.worldScreen.lastFrame = currentFrame;
            const focused = state.window.getAttribute(glfw.Window.Attribute.focused);
            if (!focused and appState.app.currentScreen != .paused) {
                try appState.pauseGame();
            } else if (appState.app.currentScreen == .paused) {
                if (focused and focusedAt == 0.0) {
                    focusedAt = currentFrame;
                    std.debug.print("focusedAt: {d}\n", .{focusedAt});
                } else if (focused and (currentFrame - focusedAt) > 0.07) {
                    focusedAt = 0.0;
                    try appState.resumeGame();
                }
            }

            if (try ctrls.handleKey()) {
                try appState.exitGame();
            }
            if (state.quit) {
                break :main_loop;
            }
            if (appState.exit) {
                break :main_loop;
            }

            const fb_size = state.window.getFramebufferSize();
            const w: u32 = @intCast(fb_size[0]);
            const h: u32 = @intCast(fb_size[1]);
            zgui.backend.newFrame(w, h);
            _ = blecs.ecs.progress(state.world, 0);
            // switch (appState.app.currentScreen) {
            //     .game => {
            //         const time = ecs.get(state.world, state.entities.clock, components.Time);
            //         try drawGameScreen(&gameScreen, &gameUI, @constCast(time));
            //     },
            //     .textureGenerator => {
            //         try drawTextureGeneratorScreen(&textureGen, &gameUI);
            //     },
            //     .worldEditor => {
            //         try drawWorldEditorScreen(&gameUI);
            //     },
            //     .blockEditor => {
            //         try drawBlockEditorScreen(&textureGen, &gameUI);
            //     },
            //     .chunkGenerator => {
            //         try drawChunkGeneratorScreen(&demoScreen, &gameUI);
            //     },
            //     .characterDesigner => {
            //         try drawCharacterDesignerScreen(&characterScreen, &gameUI);
            //     },
            //     .paused => {
            //         window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
            //     },
            // }
            zgui.backend.draw();
            state.window.swapBuffers();
        }
    }
};

fn drawTextureGeneratorScreen(textureGen: *screen.texture_gen.TextureGenerator, gameUI: *ui.UI) !void {
    try textureGen.draw();
    try gameUI.drawTextureGen();
}

fn drawGameScreen(gameScreen: *screen.world.World, gameUI: *ui.UI, time: ?*blecs.components.Time) !void {
    try gameScreen.draw();
    try gameUI.drawGame(time);
}

fn drawWorldEditorScreen(gameUI: *ui.UI) !void {
    try gameUI.drawWorldEditor();
}

fn drawBlockEditorScreen(textureGen: *screen.texture_gen.TextureGenerator, gameUI: *ui.UI) !void {
    try textureGen.draw();
    try gameUI.drawBlockEditor();
}

fn drawChunkGeneratorScreen(demoScreen: *screen.world.World, gameUI: *ui.UI) !void {
    try demoScreen.draw();
    try gameUI.drawChunkGenerator();
}
fn drawCharacterDesignerScreen(characterScreen: *screen.character.Character, gameUI: *ui.UI) !void {
    try characterScreen.draw();
    try gameUI.drawCharacterDesigner();
}
