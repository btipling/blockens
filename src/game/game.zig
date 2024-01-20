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
const chunk = @import("chunk.zig");

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

pub const Game = struct {
    allocator: std.mem.Allocator,
    sqliteAlloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, sqliteAlloc: std.mem.Allocator) !Game {
        return .{
            .allocator = allocator,
            .sqliteAlloc = sqliteAlloc,
        };
    }

    pub fn deinit(self: *Game) void {
        _ = self;
        std.debug.print("\nGoodbye btzig-blockens!\n", .{});
    }

    pub fn run(self: *Game) !void {
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

        zgui.backend.init(window);
        defer zgui.backend.deinit();

        zmesh.init(self.allocator);
        defer zmesh.deinit();

        zstbi.init(self.allocator);
        defer zstbi.deinit();
        zstbi.setFlipVerticallyOnLoad(false);

        var appState = try state.State.init(self.allocator, self.sqliteAlloc);
        defer appState.deinit();

        var gameUI = try ui.UI.init(&appState, window, self.allocator);
        defer gameUI.deinit();

        // init view imports
        const planePosition = position.Position{ .x = 0.0, .y = 0.0, .z = -1.0 };
        var worldPlane = try plane.Plane.init("worldplane", planePosition, self.allocator);
        defer worldPlane.deinit();
        var uiCursor = try cursor.Cursor.init("cursor", self.allocator);
        defer uiCursor.deinit();

        // init views
        var gameWorld = try world.World.initWithHUD(worldPlane, uiCursor, &appState.worldView);
        const worldDims = 1;
        const chunks = worldDims * worldDims;
        for (0..chunks) |i| {
            const x = @as(gl.Float, @floatFromInt(@mod(i, worldDims)));
            const y = 0;
            const z = @as(gl.Float, @floatFromInt(i / worldDims));
            const pos = position.Position{ .x = x - worldDims / 2, .y = y, .z = z - worldDims / 2 };
            const cData = appState.demoView.randomChunk(i);
            try appState.worldView.initChunk(cData, pos);
        }
        try appState.worldView.writeChunks();

        var textureGen = try texture_gen.TextureGenerator.init(&appState, self.allocator);
        defer textureGen.deinit();
        var demoWorld = try world.World.init(&appState.demoView);
        {
            const cData = appState.demoView.randomChunk(9001);
            try appState.demoView.initChunk(cData, position.Position{ .x = 0, .y = 0, .z = 0 });
        }
        try appState.demoView.writeChunks();

        var c = try controls.Controls.init(window, &appState);
        ctrls = &c;
        _ = window.setCursorPosCallback(cursorPosCallback);
        const skyColor = [4]gl.Float{ 0.5294117647, 0.80784313725, 0.92156862745, 1.0 };

        // uncomment to start in a specific view:
        // try appState.setGameView();
        try appState.setChunkGeneratorView();

        var focusedAt: gl.Float = 0.0;
        main_loop: while (!window.shouldClose()) {
            glfw.pollEvents();

            const currentFrame: gl.Float = @as(gl.Float, @floatCast(glfw.getTime()));
            appState.worldView.deltaTime = currentFrame - appState.worldView.lastFrame;
            appState.worldView.lastFrame = currentFrame;
            const focused = window.getAttribute(glfw.Window.Attribute.focused);
            if (!focused and appState.app.view != .paused) {
                try appState.pauseGame();
            } else if (appState.app.view == .paused) {
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
            if (appState.exit) {
                break :main_loop;
            }
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.clearBufferfv(gl.COLOR, 0, &skyColor);
            // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

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
                    try drawBlockEditorView(&textureGen, &gameUI);
                },
                .chunkGenerator => {
                    try drawChunkGeneratorView(&demoWorld, &gameUI);
                },
                .paused => {
                    window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
                },
            }
            // gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
            window.swapBuffers();
        }
    }
};

fn drawTextureGeneratorView(textureGen: *texture_gen.TextureGenerator, gameUI: *ui.UI) !void {
    try textureGen.draw();
    try gameUI.drawTextureGen();
}

fn drawGameView(gameWorld: *world.World, gameUI: *ui.UI) !void {
    try gameWorld.draw();
    try gameUI.drawGame();
}

fn drawWorldEditorView(gameUI: *ui.UI) !void {
    try gameUI.drawWorldEditor();
}

fn drawBlockEditorView(textureGen: *texture_gen.TextureGenerator, gameUI: *ui.UI) !void {
    try textureGen.draw();
    try gameUI.drawBlockEditor();
}

fn drawChunkGeneratorView(demoWorld: *world.World, gameUI: *ui.UI) !void {
    try demoWorld.draw();
    try gameUI.drawChunkGenerator();
}
