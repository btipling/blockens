const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const position = @import("position.zig");
const config = @import("config.zig");
const cube = @import("./shape/cube.zig");
const view = @import("./shape/view.zig");
const instancedShape = @import("./shape/instanced_shape.zig");
const data = @import("./data/data.zig");

pub const StateErrors = error{
    NoBlocks,
    InvalidBlockID,
};

pub const State = struct {
    app: App,
    worldView: ViewState,
    db: data.Data,

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
        var s = State{
            .app = try App.init(),
            .worldView = try ViewState.init(alloc),
            .db = db,
        };
        try s.worldView.initBlocks(&s);
        return s;
    }

    pub fn deinit(self: *State) void {
        self.worldView.deinit();
    }
};

pub const View = enum {
    game,
    textureGenerator,
    worldEditor,
    blockEditor,
};

pub const App = struct {
    view: View = View.game,
    demoCubeVersion: u32 = 0,
    demoTextureColors: ?[data.RGBAColorTextureSize]gl.Uint,

    pub fn init() !App {
        return App{
            .view = View.game,
            .demoCubeVersion = 0,
            .demoTextureColors = null,
        };
    }

    fn clearViewState(self: *App) void {
        self.demoCubeVersion += 1;
        self.demoTextureColors = null;
    }

    pub fn setGameView(self: *App) !void {
        self.clearViewState();
        self.view = View.game;
    }

    pub fn setTextureGeneratorView(self: *App) !void {
        self.clearViewState();
        self.view = View.textureGenerator;
    }

    pub fn setWorldEditorView(self: *App) !void {
        self.clearViewState();
        self.view = View.worldEditor;
    }

    pub fn setBlockEditorView(self: *App) !void {
        self.clearViewState();
        self.view = View.blockEditor;
    }

    pub fn setTextureColor(self: *App, demoTextureColors: [data.RGBAColorTextureSize]gl.Uint) void {
        self.demoTextureColors = demoTextureColors;
        self.demoCubeVersion += 1;
    }
};

pub const ViewState = struct {
    alloc: std.mem.Allocator,
    view: view.View,
    blockOptions: std.ArrayList(data.blockOption),
    cubesMap: std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShape)),
    cameraPos: @Vector(4, gl.Float),
    cameraFront: @Vector(4, gl.Float),
    cameraUp: @Vector(4, gl.Float),
    lookAt: zm.Mat,
    lastFrame: gl.Float,
    deltaTime: gl.Float,
    firstMouse: bool,
    lastX: gl.Float,
    lastY: gl.Float,
    yaw: gl.Float,
    pitch: gl.Float,
    highlightedIndex: ?usize = 0,

    pub fn init(alloc: std.mem.Allocator) !ViewState {
        var g = ViewState{
            .alloc = alloc,
            .view = try view.View.init(zm.identity()),
            .blockOptions = std.ArrayList(data.blockOption).init(alloc),
            .cubesMap = std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShape)).init(alloc),
            .cameraPos = @Vector(4, gl.Float){ 0.0, 65.0, 3.0, 1.0 },
            .cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 },
            .cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 },
            .lookAt = zm.identity(),
            .lastFrame = 0.0,
            .deltaTime = 0.0,
            .firstMouse = true,
            .lastX = 0.0,
            .lastY = 0.0,
            .yaw = -90.0,
            .pitch = 0.0,
        };

        try ViewState.updateLookAt(&g);
        return g;
    }

    pub fn deinit(self: *ViewState) void {
        var iterator = self.cubesMap.iterator();
        while (iterator.next()) |s| {
            for (s.value_ptr.items) |shape| {
                shape.deinit();
            }
            s.value_ptr.deinit();
        }
        self.cubesMap.deinit();
        self.blockOptions.deinit();
    }

    pub fn initBlocks(self: *ViewState, appState: *State) !void {
        try appState.db.listBlocks(&self.blockOptions);
    }

    pub fn addBlocks(self: *ViewState, appState: *State, blockOptionId: u32) !usize {
        if (self.blockOptions.items.len == 0) {
            return StateErrors.NoBlocks;
        }
        for (self.blockOptions.items) |blockOption| {
            if (blockOption.id != blockOptionId) {
                continue;
            }
            var s = try cube.Cube.initBlockCube(&self.view, appState, blockOption.id, self.alloc);
            _ = &s;
            if (self.cubesMap.get(blockOption.id)) |shapes| {
                var _shapes = shapes;
                try _shapes.append(s);
                try self.cubesMap.put(blockOption.id, _shapes);
                return _shapes.items.len - 1;
            } else {
                var shapes = std.ArrayList(instancedShape.InstancedShape).init(self.alloc);
                try shapes.append(s);
                try self.cubesMap.put(blockOption.id, shapes);
                return 0;
            }
        }
        std.debug.print("Invalid block id: {}\n", .{blockOptionId});
        return StateErrors.InvalidBlockID;
    }

    pub fn updateCameraPosition(self: *ViewState, updatedCameraPosition: @Vector(4, gl.Float)) !void {
        self.cameraPos = updatedCameraPosition;
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn updateCameraFront(self: *ViewState, updatedCameraFront: @Vector(4, gl.Float)) !void {
        self.cameraFront = updatedCameraFront;
        try self.updateLookAt();
        try self.pickObject();
    }

    fn updateLookAt(self: *ViewState) !void {
        self.lookAt = zm.lookAtRh(
            self.cameraPos,
            self.cameraPos + self.cameraFront,
            self.cameraUp,
        );
        try self.view.update(self.lookAt);
    }

    fn pickObject(self: *ViewState) !void {
        _ = self;
        // var currentPos = self.cameraPos;
        // const maxRayLength = 100;
        // var found = false;
        // for (0..maxRayLength) |i| {
        //     if (i == maxRayLength) {
        //         return;
        //     }
        //     const checkDistance = @as(gl.Float, @floatFromInt(i));
        //     const cdV: @Vector(4, gl.Float) = @splat(checkDistance);
        //     const distance = @as(@Vector(4, gl.Float), cdV);
        //     currentPos = @floor(self.cameraPos + (distance * self.cameraFront));
        //     for (self.blocks.items, 0..) |block, j| {
        //         if (block.position.x == currentPos[0] and block.position.y == currentPos[1] and block.position.z == currentPos[2]) {
        //             if (self.highlightedIndex) |hi| {
        //                 if (hi == j) {
        //                     return;
        //                 }
        //                 self.blocks.items[hi].shape.highlight = 0;
        //             }
        //             self.highlightedIndex = j;
        //             self.blocks.items[j].shape.highlight = 1;
        //             found = true;
        //         }
        //     }
        // }
        // if (!found) {
        //     if (self.highlightedIndex) |hi| {
        //         if (self.blocks.items.len > hi) {
        //             self.blocks.items[hi].shape.highlight = 0;
        //         }
        //     }
        //     self.highlightedIndex = null;
        // }
    }
};
