const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const position = @import("position.zig");
const config = @import("config.zig");
const cube = @import("./shape/cube.zig");
const view = @import("./shape/view.zig");
const voxelShape = @import("./shape/voxel_shape.zig");
const voxelMesh = @import("./shape/voxel_mesh.zig");
const data = @import("./data/data.zig");

pub const StateErrors = error{
    NoBlocks,
    InvalidBlockID,
};

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

pub const State = struct {
    app: App,
    worldView: ViewState,
    demoView: ViewState,
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
        const v = try view.View.init(zm.identity());
        var demoTransform = zm.identity();
        demoTransform = zm.mul(demoTransform, zm.scalingV(@Vector(4, gl.Float){ 0.005, 0.005, 0.005, 0.0 }));
        demoTransform = zm.mul(demoTransform, zm.rotationX(0.05 * std.math.pi * 2.0));
        demoTransform = zm.mul(demoTransform, zm.translationV(@Vector(4, gl.Float){ -0.7995, 0.401, -1.0005, 0.0 }));
        var s = State{
            .app = try App.init(),
            .worldView = try ViewState.init(
                alloc,
                v,
                @Vector(4, gl.Float){ -68.0, 78.0, -70.0, 1.0 },
                @Vector(4, gl.Float){ 0.459, -0.31, 0.439, 0.0 },
                41.6,
                -19.4,
                zm.translationV(@Vector(4, gl.Float){ -32.0, 0.0, -32.0, 0.0 }),
                zm.identity(),
            ),
            .demoView = try ViewState.init(
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
        try s.worldView.initBlocks(&s);
        try s.demoView.initBlocks(&s);
        return s;
    }

    fn clearViewState(self: *State) !void {
        try self.app.clearViewState();
        try self.worldView.clearViewState();
        try self.demoView.clearViewState();
    }

    pub fn deinit(self: *State) void {
        self.worldView.deinit();
        self.demoView.deinit();
        self.db.deinit();
    }

    pub fn setGameView(self: *State) !void {
        try self.clearViewState();
        try self.worldView.focusView();
        self.app.view = View.game;
    }

    pub fn setTextureGeneratorView(self: *State) !void {
        try self.clearViewState();
        self.app.view = View.textureGenerator;
    }

    pub fn setWorldEditorView(self: *State) !void {
        try self.clearViewState();
        self.app.view = View.worldEditor;
    }

    pub fn setBlockEditorView(self: *State) !void {
        try self.clearViewState();
        self.app.view = View.blockEditor;
    }

    pub fn setChunkGeneratorView(self: *State) !void {
        try self.clearViewState();
        try self.demoView.focusView();
        self.app.view = View.chunkGenerator;
    }
};

pub const View = enum {
    game,
    textureGenerator,
    worldEditor,
    blockEditor,
    chunkGenerator,
};

pub const App = struct {
    view: View = View.game,
    demoCubeVersion: u32 = 0,
    demoTextureColors: ?[data.RGBAColorTextureSize]gl.Uint,
    showChunkGeneratorUI: bool = true,

    pub fn init() !App {
        return App{
            .view = View.game,
            .demoCubeVersion = 0,
            .demoTextureColors = null,
        };
    }

    pub fn toggleChunkGeneratorUI(self: *App) !void {
        self.showChunkGeneratorUI = !self.showChunkGeneratorUI;
    }

    fn clearViewState(self: *App) !void {
        self.demoCubeVersion += 1;
        self.demoTextureColors = null;
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
    voxelMesh: voxelMesh.VoxelMesh,
    shapes: std.ArrayList(voxelShape.VoxelShape),
    cameraPos: @Vector(4, gl.Float),
    cameraFront: @Vector(4, gl.Float),
    cameraUp: @Vector(4, gl.Float),
    worldTransform: zm.Mat,
    screenTransform: zm.Mat,
    lookAt: zm.Mat,
    lastFrame: gl.Float,
    deltaTime: gl.Float,
    firstMouse: bool,
    lastX: gl.Float,
    lastY: gl.Float,
    yaw: gl.Float,
    pitch: gl.Float,
    highlightedIndex: ?usize = 0,
    disableScreenTransform: bool,
    pub fn init(
        alloc: std.mem.Allocator,
        v: view.View,
        initialCameraPos: @Vector(4, gl.Float),
        initialCameraFront: @Vector(4, gl.Float),
        initialYaw: gl.Float,
        initialPitch: gl.Float,
        worldTransform: zm.Mat,
        screenTransform: zm.Mat,
    ) !ViewState {
        var g = ViewState{
            .alloc = alloc,
            .view = v,
            .blockOptions = std.ArrayList(data.blockOption).init(alloc),
            .voxelMesh = try voxelMesh.VoxelMesh.init(v, alloc),
            .shapes = std.ArrayList(voxelShape.VoxelShape).init(alloc),
            .cameraPos = initialCameraPos,
            .cameraFront = initialCameraFront,
            .cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 },
            .worldTransform = worldTransform,
            .screenTransform = screenTransform,
            .lookAt = zm.identity(),
            .lastFrame = 0.0,
            .deltaTime = 0.0,
            .firstMouse = true,
            .lastX = 0.0,
            .lastY = 0.0,
            .yaw = initialYaw,
            .pitch = initialPitch,
            .disableScreenTransform = false,
        };

        try ViewState.updateLookAt(&g);
        return g;
    }

    pub fn deinit(self: *ViewState) void {
        self.voxelMesh.deinit();
        self.shapes.deinit();
        self.blockOptions.deinit();
    }

    fn clearViewState(self: *ViewState) !void {
        self.view.unbind();
    }

    pub fn toggleScreenTransform(self: *ViewState) !void {
        self.disableScreenTransform = !self.disableScreenTransform;
        try self.updateLookAt();
    }

    fn focusView(self: *ViewState) !void {
        self.view.bind();
        try self.updateLookAt();
    }

    pub fn initBlocks(self: *ViewState, appState: *State) !void {
        try appState.db.listBlocks(&self.blockOptions);
    }

    pub fn rotateWorld(self: *ViewState) !void {
        const r = zm.rotationY(0.0125 * std.math.pi * 2.0);
        self.worldTransform = zm.mul(self.worldTransform, r);
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn rotateWorldInReverse(self: *ViewState) !void {
        const r = zm.rotationY(-0.0125 * std.math.pi * 2.0);
        self.worldTransform = zm.mul(self.worldTransform, r);
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn updateCameraPosition(self: *ViewState, updatedCameraPosition: @Vector(4, gl.Float)) !void {
        self.cameraPos = updatedCameraPosition;
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn updateCameraFront(self: *ViewState, pitch: gl.Float, yaw: gl.Float, lastX: gl.Float, lastY: gl.Float, updatedCameraFront: @Vector(4, gl.Float)) !void {
        self.pitch = pitch;
        self.yaw = yaw;
        self.lastX = lastX;
        self.lastY = lastY;
        self.firstMouse = false;
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
        const m = zm.mul(self.worldTransform, self.lookAt);
        if (self.disableScreenTransform) {
            try self.view.update(m);
            return;
        }
        try self.view.update(zm.mul(m, self.screenTransform));
    }

    pub fn randomChunk(self: *ViewState, seed: u64) [chunkSize]i32 {
        var prng = std.rand.DefaultPrng.init(seed + @as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();
        const maxOptions = self.blockOptions.items.len - 1;
        var chunk: [chunkSize]i32 = [_]i32{undefined} ** chunkSize;
        for (chunk, 0..) |_, i| {
            const randomInt = random.uintAtMost(usize, maxOptions);
            const blockId = @as(i32, @intCast(randomInt + 1));
            chunk[i] = blockId;
        }
        return chunk;
    }

    pub fn initChunk(self: *ViewState, appState: *State, chunk: [chunkSize]i32, alloc: std.mem.Allocator, chunkPosition: position.Position) !void {
        self.view.bind();
        var blockTransforms = std.ArrayList(voxelShape.VoxelShape).init(alloc);
        defer blockTransforms.deinit();

        try blockTransforms.ensureTotalCapacity(1);
        for (chunk, 0..) |blockId, i| {
            if (blockId == 0) {
                continue;
            }
            const x = @as(gl.Float, @floatFromInt(@mod(i, chunkDim))) + (chunkPosition.x * chunkDim);
            const y = @as(gl.Float, @floatFromInt(@mod(i / chunkDim, chunkDim))) + (chunkPosition.y * chunkDim);
            const z = @as(gl.Float, @floatFromInt(i / (chunkDim * chunkDim))) + (chunkPosition.z * chunkDim);
            const m = zm.translation(x, y, z);
            var worldTransform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&worldTransform, m);
            const voxel = try self.voxelMesh.initVoxel(
                appState,
                blockId,
                worldTransform,
            );
            blockTransforms.appendAssumeCapacity(voxel);
            if (blockTransforms.items.len > 0) {
                break;
            }
        }
        try self.shapes.appendSlice(blockTransforms.items);

        self.view.unbind();
    }

    pub fn clearChunks(self: *ViewState) !void {
        self.view.bind();
        self.shapes.clearRetainingCapacity();
        self.view.unbind();
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
