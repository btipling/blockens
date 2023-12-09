const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zmesh = @import("zmesh");
const cfg = @import("config.zig");
const ui = @import("ui/ui.zig");
const controls = @import("controls.zig");
const block = @import("block.zig");
const cube = @import("cube.zig");
const position = @import("position.zig");
const world = @import("world.zig");

const embedded_font_data = @embedFile("assets/fonts/PressStart2P-Regular.ttf");

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
    const window = glfw.Window.create(cfg.windows_width, cfg.windows_height, cfg.game_name, null) catch {
        std.log.err("Failed to create game window.", .{});
        return;
    };
    defer window.destroy();
    window.setSizeLimits(800, 800, -1, -1);
    window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.hidden);

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
    var blocks = std.ArrayList(*block.Block).init(allocator);

    const initialTestBlockPosition = position.Position{ .worldX = 0.0, .worldY = 0.0, .worldZ = 0.0 };
    var testBlock = try block.Block.init("testblock", initialTestBlockPosition);
    defer testBlock.deinit();

    const initialTestCubePosition = position.Position{ .worldX = 0.0, .worldY = 0.0, .worldZ = 0.0 };
    var testCube = try cube.Cube.init("testcube", initialTestCubePosition, allocator);
    defer testCube.deinit();

    try blocks.append(&testBlock);
    var gameWorld = try world.World.init(testCube, blocks);

    main_loop: while (!window.shouldClose()) {
        glfw.pollEvents();
        const quit = try controls.handleKey(window);
        if (quit) {
            break :main_loop;
        }
        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.0, 0.0, 0.0, 1.0 });
        gl.enable(gl.BLEND); // enable transparency
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        try gameUI.draw();
        try gameWorld.draw();

        window.swapBuffers();
    }
}
