const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const texture_gen = @import("texture_gen.zig");
const world_editor = @import("world_editor.zig");
const block_editor = @import("block_editor.zig");
const chunk_generator = @import("chunk_generator.zig");
const game = @import("game.zig");
const state = @import("../state.zig");
const script = @import("../script/script.zig");

const pressStart2PFont = @embedFile("../assets/fonts/PressStart2P/PressStart2P-Regular.ttf");
const robotoMonoFont = @embedFile("../assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");

pub const UI = struct {
    window: *glfw.Window,
    script: script.Script,
    Game: game.Game,
    TextureGen: texture_gen.TextureGen,
    WorldEditor: world_editor.WorldEditor,
    BlockEditor: block_editor.BlockEditor,
    ChunkGenerator: chunk_generator.ChunkGenerator,

    pub fn init(appState: *state.State, window: *glfw.Window, alloc: std.mem.Allocator) !UI {
        const sc = try script.Script.init(alloc);
        var font_size: f32 = 24.0;
        const gameFont = zgui.io.addFontFromMemory(pressStart2PFont, std.math.floor(font_size * 1.1));
        zgui.io.setDefaultFont(gameFont);
        font_size = 40.0;
        const codeFont = zgui.io.addFontFromMemory(robotoMonoFont, std.math.floor(font_size * 1.1));
        return UI{
            .window = window,
            .script = sc,
            .Game = game.Game{ .appState = appState },
            .TextureGen = try texture_gen.TextureGen.init(appState, codeFont, sc, alloc),
            .WorldEditor = try world_editor.WorldEditor.init(appState, codeFont, alloc),
            .BlockEditor = try block_editor.BlockEditor.init(appState, codeFont, sc, alloc),
            .ChunkGenerator = try chunk_generator.ChunkGenerator.init(appState, codeFont, sc, alloc),
        };
    }

    pub fn deinit(self: *UI) void {
        self.TextureGen.deinit();
        self.BlockEditor.deinit();
        self.WorldEditor.deinit();
        self.script.deinit();
    }

    pub fn drawGame(self: *UI) !void {
        try self.Game.draw(self.window);
    }

    pub fn drawTextureGen(self: *UI) !void {
        try self.TextureGen.draw(self.window);
        self.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    }

    pub fn drawWorldEditor(self: *UI) !void {
        try self.WorldEditor.draw(self.window);
        self.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    }

    pub fn drawBlockEditor(self: *UI) !void {
        try self.BlockEditor.draw(self.window);
        self.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    }

    pub fn drawChunkGenerator(self: *UI) !void {
        try self.ChunkGenerator.draw(self.window);
        self.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    }
};
