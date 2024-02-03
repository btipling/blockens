const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const shapeview = @import("../shape/view.zig");
const config = @import("../config.zig");
const data = @import("../data/data.zig");

pub const position = @import("position.zig");
pub const app = @import("app.zig");
pub const screen = @import("screen.zig");
pub const character = @import("character.zig");

pub const StateErrors = error{
    NoBlocks,
    InvalidBlockID,
};

pub const State = struct {
    app: app.App,
    character: character.Character,
    worldScreen: screen.Screen,
    demoScreen: screen.Screen,
    db: data.Data,
    exit: bool = false,

    pub fn init(alloc: std.mem.Allocator, sqliteAlloc: std.mem.Allocator) !State {
        var db = try data.Data.init(sqliteAlloc);
        db.ensureSchema() catch |err| {
            std.log.err("Failed to ensure schema: {}\n", .{err});
            return err;
        };
        db.ensureDefaultWorld() catch |err| {
            std.log.err("Failed to ensure default world: {}\n", .{err});
            return err;
        };
        const v = try shapeview.View.init(zm.identity());
        var demoTransform = zm.identity();
        demoTransform = zm.mul(demoTransform, zm.scalingV(@Vector(4, gl.Float){ 0.005, 0.005, 0.005, 0.0 }));
        demoTransform = zm.mul(demoTransform, zm.rotationX(0.05 * std.math.pi * 2.0));
        demoTransform = zm.mul(demoTransform, zm.translationV(@Vector(4, gl.Float){ -0.7995, 0.401, -1.0005, 0.0 }));
        var s = State{
            .app = try app.App.init(),
            .character = try character.Character.init(alloc),
            .worldScreen = try screen.Screen.init(
                alloc,
                v,
                @Vector(4, gl.Float){ -68.0, 78.0, -70.0, 1.0 },
                @Vector(4, gl.Float){ 0.459, -0.31, 0.439, 0.0 },
                41.6,
                -19.4,
                zm.translationV(@Vector(4, gl.Float){ -32.0, 0.0, -32.0, 0.0 }),
                zm.identity(),
            ),
            .demoScreen = try screen.Screen.init(
                alloc,
                v,
                @Vector(4, gl.Float){ -68.0, 78.0, -70.0, 1.0 },
                @Vector(4, gl.Float){ 0.459, -0.31, 0.439, 0.0 },
                41.6,
                -19.4,
                zm.translationV(@Vector(4, gl.Float){ -32.0, 0.0, -32.0, 0.0 }),
                demoTransform,
            ),
            .db = db,
        };
        try s.worldScreen.initBlocks(&s);
        try s.demoScreen.initBlocks(&s);
        return s;
    }

    pub fn clearScreenState(self: *State, newScreen: screen.Screens) !void {
        self.app.previousScreen = newScreen;
        self.app.currentScreen = newScreen;
        try self.app.clearScreenState();
        try self.worldScreen.clearScreenState();
        try self.demoScreen.clearScreenState();
        try self.character.clearCharacterViewState();
    }

    pub fn deinit(self: *State) void {
        self.worldScreen.deinit();
        self.demoScreen.deinit();
        self.db.deinit();
    }

    pub fn setGameScreen(self: *State) !void {
        try self.worldScreen.focusScreen();
        try self.clearScreenState(screen.Screens.game);
    }

    pub fn setTextureGeneratorScreen(self: *State) !void {
        try self.clearScreenState(screen.Screens.textureGenerator);
    }

    pub fn setWorldEditorScreen(self: *State) !void {
        try self.clearScreenState(screen.Screens.worldEditor);
    }

    pub fn setBlockEditorScreen(self: *State) !void {
        try self.clearScreenState(screen.Screens.blockEditor);
    }

    pub fn setCharacterDesignerScreen(self: *State) !void {
        try self.character.focusView();
        try self.clearScreenState(screen.Screens.characterDesigner);
    }

    pub fn setChunkGeneratorScreen(self: *State) !void {
        try self.demoScreen.focusScreen();
        try self.clearScreenState(screen.Screens.chunkGenerator);
    }

    pub fn pauseGame(self: *State) !void {
        self.app.currentScreen = screen.Screens.paused;
    }

    pub fn resumeGame(self: *State) !void {
        if (self.app.previousScreen == .game) {
            try self.worldScreen.focusScreen();
        }
        self.app.currentScreen = self.app.previousScreen;
    }

    pub fn exitGame(self: *State) !void {
        self.exit = true;
    }
};
