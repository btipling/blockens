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
const cube = @import("cube.zig");
const plane = @import("plane.zig");
const cursor = @import("cursor.zig");
const position = @import("position.zig");
const world = @import("world.zig");
const texture_gen = @import("texture_gen.zig");
const state = @import("state.zig");

var ctrls: *controls.Controls = undefined;

fn cursorPosCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    ctrls.cursorPosCallback(xpos, ypos);
}

pub const Game = struct {
    window: glfw.Window,
    gl_major: comptime_int,
    gl_minor: comptime_int,
    arenaAllocator: std.heap.ArenaAllocator,
    allocator: *std.mem.Allocator,
    state: state.State,
    ui: ui.UI,
    cursor: cursor.Cursor,
    worldPlane: plane.Plane,
    textureGen: texture_gen.TextureGenerator,
    world: world.World,
    controls: controls.Controls,

    pub fn init() !Game {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const appState = try state.State.init(allocator);

        var g = Game{
            .window = undefined,
            .gl_major = 4,
            .gl_minor = 6,
            .arenaAllocator = arena,
            .allocator = allocator,
            .state = appState,
        };
        g.window = try g.initWindow();
        try Game.initGl(&g);
        try Game.initLibs(&g);
        try Game.initViews(&g);
        try Game.initControls(&g);
        return g;
    }

    pub fn deinit(self: Game) !void {
        glfw.terminate();
        self.window.destroy();
        self.arenaAllocator.deinit();
        zgui.deinit();
        zgui.backend.deinit();
        zmesh.deinit();
        zstbi.deinit();
        self.state.deinit();
        self.cursor.deinit();
        self.worldPlane.deinit();
        self.ui.deinit();
        self.textureGen.deinit();
    }

    fn initWindow() !glfw.Window {
        glfw.init() catch |err| {
            std.log.err("Failed to initialize GLFW library.", .{});
            return err;
        };

        const gl_major = 4;
        const gl_minor = 6;
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

    fn initGl(self: *Game) !void {
        try gl.loadCoreProfile(glfw.getProcAddress, self.gl_major, self.gl_minor);
        const dimensions: [2]i32 = self.window.getSize();
        const w = dimensions[0];
        const h = dimensions[1];
        std.debug.print("Window size is {d}x{d}\n", .{ w, h });
        gl.enable(gl.BLEND); // enable transparency
        gl.enable(gl.DEPTH_TEST); // enable depth testing
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        // culling
        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
    }

    fn initLibs(self: *Game) !void {
        zgui.init(self.allocator);
        zgui.backend.init(self.window);
        zmesh.init(self.allocator);
        zstbi.init(self.allocator);
        zstbi.setFlipVerticallyOnLoad(false);
    }

    fn initViews(self: *Game) !void {
        const planePosition = position.Position{ .x = 0.0, .y = 0.0, .z = -1.0 };
        self.worldPlane = try plane.Plane.init("worldplane", planePosition, self.allocator);
        self.cursor = try cursor.Cursor.init("cursor", self.allocator);
        self.ui = try ui.UI.init(&self.state, self.window, self.allocator);
        self.world = try world.World.init(self.worldPlane, self.cursor, &self.state);
        self.textureGen = try texture_gen.TextureGenerator.init(&self.state, self.allocator);
    }

    fn initControls(self: *Game) !void {
        self.controls = try controls.Controls.init(self.window, &self.state);
        _ = self.window.setCursorPosCallback(cursorPosCallback);
    }

    pub fn run(self: *Game) !void {
        std.debug.print("\nRunning btzig-blockens!\n", .{});

        // temporary change to work on texture generator
        // appState.app.view = state.View.textureGenerator;

        const skyColor = [4]gl.Float{ 0.5294117647, 0.80784313725, 0.92156862745, 1.0 };
        var appState = &self.state;
        main_loop: while (!self.window.shouldClose()) {
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
                    try self.drawGameView();
                },
                .textureGenerator => {
                    try self.drawTextureGeneratorView();
                },
            }

            self.window.swapBuffers();
        }
    }

    fn drawTextureGeneratorView(self: *Game) !void {
        try &(self.textureGen).draw();
        try &(self.ui).drawTextureGen();
        return;
    }

    fn drawGameView(self: *Game) !void {
        try &(self.world).draw();
        try &(self.ui).drawGame();
    }

    fn drawWorldEditorView(_: *Game) !void {
        return;
    }

    fn drawBlockEditorView(_: *Game) !void {
        return;
    }
};
