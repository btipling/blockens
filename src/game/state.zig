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
    cubesMap: std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShape)),
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
            .cubesMap = std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShape)).init(alloc),
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

    pub fn randomChunk(self: *ViewState, seed: u64) [chunkSize]u32 {
        var prng = std.rand.DefaultPrng.init(seed + @as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();
        const maxOptions = self.blockOptions.items.len - 1;
        var chunk: [chunkSize]u32 = [_]u32{undefined} ** chunkSize;
        for (chunk, 0..) |_, i| {
            const randomInt = random.uintAtMost(usize, maxOptions);
            const blockId = @as(u32, @intCast(randomInt + 1));
            chunk[i] = blockId;
        }
        return chunk;
    }

    pub fn initChunk(self: *ViewState, appState: *State, chunk: [chunkSize]u32, alloc: std.mem.Allocator, chunkPosition: position.Position) !void {
        self.view.bind();
        var perBlockTransforms = std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShapeTransform)).init(alloc);
        defer perBlockTransforms.deinit();
        for (chunk, 0..) |blockId, i| {
            if (blockId == 0) {
                continue;
            }
            const x = @as(gl.Float, @floatFromInt(@mod(i, chunkDim))) + (chunkPosition.x * chunkDim);
            const y = @as(gl.Float, @floatFromInt(@mod(i / chunkDim, chunkDim))) + (chunkPosition.y * chunkDim);
            const z = @as(gl.Float, @floatFromInt(i / (chunkDim * chunkDim))) + (chunkPosition.z * chunkDim);
            const m = zm.translation(x, y, z);
            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&transform, m);
            const t = instancedShape.InstancedShapeTransform{ .transform = transform };

            if (perBlockTransforms.get(blockId)) |blockTransforms| {
                var _blockTransforms = blockTransforms;
                try _blockTransforms.append(t);
                if (_blockTransforms.items.len == drawSize) {
                    try self.writeAndClear(appState, blockId, &_blockTransforms);
                }
                try perBlockTransforms.put(blockId, _blockTransforms);
            } else {
                var blockTransforms = std.ArrayList(instancedShape.InstancedShapeTransform).init(alloc);
                try blockTransforms.append(t);
                try perBlockTransforms.put(blockId, blockTransforms);
            }
        }

        var keys = perBlockTransforms.keyIterator();
        while (keys.next()) |_k| {
            if (@TypeOf(_k) == *u32) {
                const k = _k.*;
                if (perBlockTransforms.get(k)) |blockTransforms| {
                    var _blockTransforms = blockTransforms;
                    try self.writeAndClear(appState, k, &_blockTransforms);
                }
            }
        }
        var values = perBlockTransforms.valueIterator();
        while (values.next()) |v| {
            v.deinit();
        }
        self.view.unbind();
    }

    pub fn writeAndClear(self: *ViewState, appState: *State, blockId: u32, blockTransforms: *std.ArrayList(instancedShape.InstancedShapeTransform)) !void {
        const transforms = blockTransforms.items;
        const addedAt = try self.addBlocks(appState, blockId);
        if (self.cubesMap.get(blockId)) |shapes| {
            var _is = shapes.items[addedAt];
            try cube.Cube.updateInstanced(transforms, &_is);
            shapes.items[addedAt] = _is;
        } else {
            std.debug.print("blockId {d} not found in cubesMap\n", .{blockId});
        }
        // reset transforms
        var _b = blockTransforms;
        _b.clearRetainingCapacity();
    }

    pub fn clearChunks(self: *ViewState) !void {
        self.view.bind();
        var keys = self.cubesMap.keyIterator();
        while (keys.next()) |_k| {
            const _blockId = _k.*;
            if (self.cubesMap.get(_blockId)) |shapes| {
                for (shapes.items) |is| {
                    var _is = is;
                    _is.deinit();
                }
                var _shapes = shapes;
                _shapes.clearRetainingCapacity();
                try self.cubesMap.put(_blockId, _shapes);
            } else {
                std.debug.print("blockId {d} not found in cubesMap\n", .{_blockId});
            }
        }
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
