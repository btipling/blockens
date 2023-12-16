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
const block = @import("block.zig");
const cube = @import("cube.zig");
const plane = @import("plane.zig");
const position = @import("position.zig");
const world = @import("world.zig");
const state = @import("state.zig");

const embedded_font_data = @embedFile("assets/fonts/PressStart2P-Regular.ttf");

var ctrls: *controls.Controls = undefined;

fn cursorPosCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    ctrls.cursorPosCallback(xpos, ypos);
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
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);
    glfw.windowHintTyped(.resizable, false);
    glfw.windowHintTyped(.maximized, true);
    const window = glfw.Window.create(cfg.windows_width, cfg.windows_height, cfg.game_name, null) catch {
        std.log.err("Failed to create game window.", .{});
        return;
    };
    defer window.destroy();
    window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    {
        const dimensions: [2]i32 = window.getSize();
        const w = dimensions[0];
        const h = dimensions[1];
        std.debug.print("Window size is {d}x{d}\n", .{ w, h });
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    zgui.init(allocator);
    defer zgui.deinit();

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    zmesh.init(allocator);
    defer zmesh.deinit();

    const font_size = 24.0;
    const font_large = zgui.io.addFontFromMemory(embedded_font_data, std.math.floor(font_size * 1.1));
    zgui.io.setDefaultFont(font_large);

    zstbi.init(allocator);
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(true);

    var gameUI = try ui.UI.init(window);
    const blocks = std.ArrayList(*block.Block).init(allocator);

    const initialTestCubeposition = position.Position{ .x = 0.0, .y = 3.0, .z = -1.0 };
    var testCube = try cube.Cube.init("testcube", initialTestCubeposition, allocator);
    defer testCube.deinit();

    const planePosition = position.Position{ .x = 0.0, .y = 0.0, .z = -1.0 };
    var worldPlane = try plane.Plane.init("worldplane", planePosition, allocator);
    defer worldPlane.deinit();

    var gameWorld = try world.World.init(worldPlane, testCube, blocks);

    var gameState = state.State.init();

    var c = try controls.Controls.init(window, &gameState);
    ctrls = &c;

    _ = window.setCursorPosCallback(cursorPosCallback);
    const skyColor = [4]gl.Float{ 0.5294117647, 0.80784313725, 0.92156862745, 1.0 };

    main_loop: while (!window.shouldClose()) {
        glfw.pollEvents();

        const currentFrame: gl.Float = @as(gl.Float, @floatCast(glfw.getTime()));
        gameState.deltaTime = currentFrame - gameState.lastFrame;
        gameState.lastFrame = currentFrame;
        const quit = try ctrls.handleKey();
        if (quit) {
            break :main_loop;
        }
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.clearBufferfv(gl.COLOR, 0, &skyColor);
        gl.enable(gl.BLEND); // enable transparency
        gl.enable(gl.DEPTH_TEST); // enable depth testing
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        var m = zm.identity();

        const lookat = zm.lookAtRh(gameState.cameraPos, gameState.cameraPos + gameState.cameraFront, gameState.cameraUp);
        m = zm.mul(m, lookat);

        try gameUI.draw();
        try gameWorld.draw(m);

        window.swapBuffers();
    }
}
