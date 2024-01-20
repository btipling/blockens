const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const position = @import("position.zig");
const chunk = @import("chunk.zig");
const config = @import("config.zig");
const cube = @import("./shape/cube.zig");
const view = @import("./shape/view.zig");
const voxelShape = @import("./shape/voxel_shape.zig");
const voxelMesh = @import("./shape/voxel_mesh.zig");
const instancedShape = @import("./shape/instanced_shape.zig");
const data = @import("./data/data.zig");

pub const StateErrors = error{
    NoBlocks,
    InvalidBlockID,
};

pub const State = struct {
    app: App,
    worldView: ViewState,
    demoView: ViewState,
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

    fn clearViewState(self: *State, newView: View) !void {
        self.app.previousView = newView;
        self.app.view = newView;
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
        try self.worldView.focusView();
        try self.clearViewState(View.game);
    }

    pub fn setTextureGeneratorView(self: *State) !void {
        try self.clearViewState(View.textureGenerator);
    }

    pub fn setWorldEditorView(self: *State) !void {
        try self.clearViewState(View.worldEditor);
    }

    pub fn setBlockEditorView(self: *State) !void {
        try self.clearViewState(View.blockEditor);
    }

    pub fn setChunkGeneratorView(self: *State) !void {
        try self.demoView.focusView();
        try self.clearViewState(View.chunkGenerator);
    }

    pub fn pauseGame(self: *State) !void {
        self.app.view = View.paused;
    }

    pub fn resumeGame(self: *State) !void {
        if (self.app.previousView == .game) {
            try self.worldView.focusView();
        }
        self.app.view = self.app.previousView;
    }

    pub fn exitGame(self: *State) !void {
        self.exit = true;
    }
};

pub const View = enum {
    game,
    textureGenerator,
    worldEditor,
    blockEditor,
    chunkGenerator,
    paused,
};

const defaultView = View.game;

pub const App = struct {
    view: View = defaultView,
    previousView: View = defaultView,
    demoCubeVersion: u32 = 0,
    demoTextureColors: ?[data.RGBAColorTextureSize]gl.Uint,
    showChunkGeneratorUI: bool = true,

    pub fn init() !App {
        return App{
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
    cubesMap: std.AutoHashMap(i32, instancedShape.InstancedShape),
    voxelMeshes: std.AutoHashMap(i32, voxelMesh.VoxelMesh),
    perBlockTransforms: std.AutoHashMap(i32, std.ArrayList(instancedShape.InstancedShapeTransform)),
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
    wireframe: bool = false,
    meshChunks: bool = false,
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
            .cubesMap = std.AutoHashMap(i32, instancedShape.InstancedShape).init(alloc),
            .voxelMeshes = std.AutoHashMap(i32, voxelMesh.VoxelMesh).init(alloc),
            .perBlockTransforms = std.AutoHashMap(i32, std.ArrayList(instancedShape.InstancedShapeTransform)).init(alloc),
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
        self.clearChunks();
        self.blockOptions.deinit();
        var cuv = self.cubesMap.valueIterator();
        while (cuv.next()) |v| {
            v.deinit();
        }
        self.cubesMap.deinit();
        var vmu = self.voxelMeshes.valueIterator();
        while (vmu.next()) |v| {
            v.deinit();
        }
        self.voxelMeshes.deinit();
        self.perBlockTransforms.deinit();
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
        for (self.blockOptions.items) |blockOption| {
            var vm = try voxelMesh.VoxelMesh.init(
                appState,
                self.view,
                blockOption.id,
                self.alloc,
            );
            _ = &vm;
            try self.voxelMeshes.put(blockOption.id, vm);
        }
        try self.addBlocks(appState);
    }

    pub fn addBlocks(self: *ViewState, appState: *State) !void {
        for (self.blockOptions.items) |blockOption| {
            var s = try cube.Cube.initBlockCube(&self.view, appState, blockOption.id, self.alloc);
            _ = &s;
            try self.cubesMap.put(blockOption.id, s);
        }
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

    pub fn randomChunk(self: *ViewState, seed: u64) !chunk.Chunk {
        var prng = std.rand.DefaultPrng.init(seed + @as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();
        var maxOptions = self.blockOptions.items.len;
        var c = try chunk.Chunk.init(self.alloc);
        if (maxOptions == 0) {
            std.debug.print("No blocks found\n", .{});
            return c;
        }
        maxOptions -= 1;

        for (c.data, 0..) |_, i| {
            const randomInt = random.uintAtMost(usize, maxOptions);
            const blockId = @as(i32, @intCast(randomInt + 1));
            c.data[i] = blockId;
        }
        return c;
    }

    pub fn write(self: *ViewState, blockId: i32, blockTransforms: *std.ArrayList(instancedShape.InstancedShapeTransform)) !void {
        const transforms = blockTransforms.items;
        if (self.cubesMap.get(blockId)) |is| {
            var _is = is;
            try cube.Cube.updateInstanced(transforms, &_is);
            try self.cubesMap.put(blockId, _is);
        } else {
            std.debug.print("blockId {d} not found in cubesMap\n", .{blockId});
        }
    }

    pub fn initChunk(self: *ViewState, c: *chunk.Chunk, chunkPosition: position.Position) !void {
        self.view.bind();
        if (self.meshChunks) {
            try c.findMeshes();

            var keys = c.meshes.keyIterator();
            while (keys.next()) |_k| {
                if (@TypeOf(_k) == *usize) {
                    const i = _k.*;
                    if (c.meshes.get(i)) |vp| {
                        const blockId = c.data[i];
                        if (self.voxelMeshes.get(blockId)) |vm| {
                            const p = chunk.getPositionAtIndex(i);
                            const x = p.x + (chunkPosition.x * chunk.chunkDim);
                            const y = p.y + (chunkPosition.y * chunk.chunkDim);
                            const z = p.z + (chunkPosition.z * chunk.chunkDim);
                            const m = zm.translation(x, y, z);
                            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
                            zm.storeMat(&transform, m);
                            var _vm = vm;
                            try _vm.initVoxel();
                            _vm.expandVoxel(vp);
                            try _vm.writeVoxel(transform);
                            std.debug.print("\n", .{});
                            try self.voxelMeshes.put(blockId, _vm);
                        } else {
                            std.debug.print("No voxel mesh for block id: {d}\n", .{blockId});
                        }
                    }
                }
            }
        }

        for (c.data, 0..) |blockId, i| {
            if (blockId == 0) {
                continue;
            }
            if (self.meshChunks and c.isMeshed(i)) {
                continue;
            }
            const p = chunk.getPositionAtIndex(i);
            const x = p.x + (chunkPosition.x * chunk.chunkDim);
            const y = p.y + (chunkPosition.y * chunk.chunkDim);
            const z = p.z + (chunkPosition.z * chunk.chunkDim);
            const m = zm.translation(x, y, z);
            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&transform, m);
            const t = instancedShape.InstancedShapeTransform{ .transform = transform };
            if (self.perBlockTransforms.get(blockId)) |blockTransforms| {
                var _blockTransforms = blockTransforms;
                try _blockTransforms.append(t);
                try self.perBlockTransforms.put(blockId, _blockTransforms);
            } else {
                var blockTransforms = std.ArrayList(instancedShape.InstancedShapeTransform).init(self.alloc);
                try blockTransforms.append(t);
                try self.perBlockTransforms.put(blockId, blockTransforms);
            }
        }
        self.view.unbind();
    }

    pub fn writeChunks(self: *ViewState) !void {
        self.view.bind();

        var keys = self.perBlockTransforms.keyIterator();
        while (keys.next()) |_k| {
            if (@TypeOf(_k) == *i32) {
                const k = _k.*;
                if (self.perBlockTransforms.get(k)) |blockTransforms| {
                    var _blockTransforms = blockTransforms;
                    try self.write(k, &_blockTransforms);
                }
            }
        }
        self.view.unbind();
    }

    pub fn toggleWireframe(self: *ViewState) void {
        self.wireframe = !self.wireframe;
    }

    pub fn toggleMeshChunks(self: *ViewState) void {
        self.meshChunks = !self.meshChunks;
    }

    pub fn initChunks(self: *ViewState, appState: *State) !void {
        self.view.bind();
        try self.addBlocks(appState);
        self.view.unbind();
    }

    pub fn clearChunks(self: *ViewState) void {
        self.view.bind();
        var values = self.voxelMeshes.valueIterator();
        while (values.next()) |v| {
            v.clear();
        }
        var cuv = self.cubesMap.valueIterator();
        while (cuv.next()) |v| {
            v.deinit();
        }
        var pbtv = self.perBlockTransforms.valueIterator();
        while (pbtv.next()) |v| {
            v.deinit();
        }
        self.perBlockTransforms.clearAndFree();
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
