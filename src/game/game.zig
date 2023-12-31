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
const position = @import("position.zig");
const world = @import("./view/world.zig");
const texture_gen = @import("./view/texture_gen.zig");
const state = @import("state.zig");

var ctrls: *controls.Controls = undefined;

fn cursorPosCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    ctrls.cursorPosCallback(xpos, ypos);
}

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

pub fn run() !void {
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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    zgui.init(allocator);
    defer zgui.deinit();

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    zmesh.init(allocator);
    defer zmesh.deinit();

    zstbi.init(allocator);
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(false);

    var appState = try state.State.init(allocator);
    defer appState.deinit();

    var gameUI = try ui.UI.init(&appState, window, allocator);
    defer gameUI.deinit();

    // init view dependencies
    const planePosition = position.Position{ .x = 0.0, .y = 0.0, .z = -1.0 };
    var worldPlane = try plane.Plane.init("worldplane", planePosition, allocator);
    defer worldPlane.deinit();
    var uiCursor = try cursor.Cursor.init("cursor", allocator);
    defer uiCursor.deinit();

    // temporary change to work on texture generator
    // appState.app.view = state.View.textureGenerator;
    // appState.app.view = state.View.worldEditor;
    appState.app.view = state.View.blockEditor;

    // init views
    var gameWorld = try world.World.init(worldPlane, uiCursor, &appState);
    var textureGen = try texture_gen.TextureGenerator.init(&appState, allocator);
    defer textureGen.deinit();

    var c = try controls.Controls.init(window, &appState);
    ctrls = &c;
    _ = window.setCursorPosCallback(cursorPosCallback);
    const skyColor = [4]gl.Float{ 0.5294117647, 0.80784313725, 0.92156862745, 1.0 };

    main_loop: while (!window.shouldClose()) {
        glfw.pollEvents();

        const currentFrame: gl.Float = @as(gl.Float, @floatCast(glfw.getTime()));
        appState.game.deltaTime = currentFrame - appState.game.lastFrame;
        appState.game.lastFrame = currentFrame;
        const quit = try ctrls.handleKey();
        if (quit) {
            break :main_loop;
        }
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.clearBufferfv(gl.COLOR, 0, &skyColor);

        switch (appState.app.view) {
            .game => {
                try drawGameView(&gameWorld, &gameUI);
            },
            .textureGenerator => {
                try drawTextureGeneratorView(&textureGen, &gameUI);
            },
            .worldEditor => {
                try drawWorldEditorView(&gameUI);
            },
            .blockEditor => {
                try drawBlockEditorView(&gameUI);
            },
        }

        window.swapBuffers();
    }
}

fn drawTextureGeneratorView(textureGen: *texture_gen.TextureGenerator, gameUI: *ui.UI) !void {
    try textureGen.draw();
    try gameUI.drawTextureGen();
    return;
}

fn drawGameView(gameWorld: *world.World, gameUI: *ui.UI) !void {
    try gameWorld.draw();
    try gameUI.drawGame();
}

fn drawWorldEditorView(gameUI: *ui.UI) !void {
    try gameUI.drawWorldEditor();
}

fn drawBlockEditorView(gameUI: *ui.UI) !void {
    try gameUI.drawBlockEditor();
}
