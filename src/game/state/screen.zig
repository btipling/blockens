const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const position = @import("position.zig");
const state = @import("state.zig");
const cube = @import("../shape/cube.zig");
const shapeview = @import("../shape/view.zig");
const data = @import("../data/data.zig");
const chunk = @import("../chunk.zig");
const instancedShape = @import("../shape/instanced_shape.zig");
const voxelMesh = @import("../shape/voxel_mesh.zig");

pub const Screens = enum {
    game,
    textureGenerator,
    worldEditor,
    blockEditor,
    chunkGenerator,
    characterDesigner,
    paused,
};

pub const defaultScreen = Screens.game;

pub const Screen = struct {
    alloc: std.mem.Allocator,
    shapeview: shapeview.View,
    blockOptions: std.ArrayList(data.blockOption),
    cubesMap: std.AutoHashMap(i32, instancedShape.InstancedShape),
    voxelMeshes: std.AutoHashMap(i32, voxelMesh.VoxelMesh),
    perBlockTransforms: std.AutoHashMap(i32, std.ArrayList(instancedShape.InstancedShapeTransform)),
    chunks: std.AutoHashMap(position.worldPosition, [chunk.chunkSize]i32),
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
    showUIMetrics: bool = false,
    showUILog: bool = false,
    pub fn init(
        alloc: std.mem.Allocator,
        v: shapeview.View,
        initialCameraPos: @Vector(4, gl.Float),
        initialCameraFront: @Vector(4, gl.Float),
        initialYaw: gl.Float,
        initialPitch: gl.Float,
        worldTransform: zm.Mat,
        screenTransform: zm.Mat,
    ) !Screen {
        var g = Screen{
            .alloc = alloc,
            .shapeview = v,
            .blockOptions = std.ArrayList(data.blockOption).init(alloc),
            .cubesMap = std.AutoHashMap(i32, instancedShape.InstancedShape).init(alloc),
            .voxelMeshes = std.AutoHashMap(i32, voxelMesh.VoxelMesh).init(alloc),
            .perBlockTransforms = std.AutoHashMap(i32, std.ArrayList(instancedShape.InstancedShapeTransform)).init(alloc),
            .chunks = std.AutoHashMap(position.worldPosition, [chunk.chunkSize]i32).init(alloc),
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
        try Screen.updateLookAt(&g);
        return g;
    }

    pub fn deinit(self: *Screen) void {
        self.clearChunks() catch |err| {
            std.debug.print("Failed to clear chunks: {}\n", .{err});
        };
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
        self.chunks.deinit();
    }

    pub fn clearScreenState(self: *Screen) !void {
        self.shapeview.unbind();
    }

    pub fn toggleScreenTransform(self: *Screen) !void {
        self.disableScreenTransform = !self.disableScreenTransform;
        try self.updateLookAt();
    }

    pub fn focusScreen(self: *Screen) !void {
        self.shapeview.bind();
        try self.updateLookAt();
    }

    pub fn initBlocks(self: *Screen, appState: *state.State) !void {
        try appState.db.listBlocks(&self.blockOptions);
        for (self.blockOptions.items) |blockOption| {
            var vm = try voxelMesh.VoxelMesh.init(
                appState,
                self.shapeview,
                blockOption.id,
                self.alloc,
            );
            _ = &vm;
            try self.voxelMeshes.put(blockOption.id, vm);
        }
        try self.addBlocks(appState);
    }

    pub fn addBlocks(self: *Screen, appState: *state.State) !void {
        for (self.blockOptions.items) |blockOption| {
            var s = try cube.Cube.initBlockCube(&self.shapeview, appState, blockOption.id, self.alloc);
            _ = &s;
            try self.cubesMap.put(blockOption.id, s);
        }
    }

    pub fn rotateWorld(self: *Screen) !void {
        const r = zm.rotationY(0.0125 * std.math.pi * 2.0);
        self.worldTransform = zm.mul(self.worldTransform, r);
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn rotateWorldInReverse(self: *Screen) !void {
        const r = zm.rotationY(-0.0125 * std.math.pi * 2.0);
        self.worldTransform = zm.mul(self.worldTransform, r);
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn updateCameraPosition(self: *Screen, updatedCameraPosition: @Vector(4, gl.Float)) !void {
        self.cameraPos = updatedCameraPosition;
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn updateCameraState(self: *Screen, lastX: gl.Float, lastY: gl.Float) void {
        self.lastX = lastX;
        self.lastY = lastY;
        self.firstMouse = false;
    }

    pub fn updateCameraFront(self: *Screen, pitch: gl.Float, yaw: gl.Float, lastX: gl.Float, lastY: gl.Float, updatedCameraFront: @Vector(4, gl.Float)) !void {
        self.updateCameraState(lastX, lastY);
        self.pitch = pitch;
        self.yaw = yaw;
        self.cameraFront = updatedCameraFront;
        try self.updateLookAt();
        try self.pickObject();
    }

    fn updateLookAt(self: *Screen) !void {
        self.lookAt = zm.lookAtRh(
            self.cameraPos,
            self.cameraPos + self.cameraFront,
            self.cameraUp,
        );
        const m = zm.mul(self.worldTransform, self.lookAt);
        if (self.disableScreenTransform) {
            try self.shapeview.update(m);
            return;
        }
        try self.shapeview.update(zm.mul(m, self.screenTransform));
    }

    pub fn write(self: *Screen, blockId: i32, blockTransforms: *std.ArrayList(instancedShape.InstancedShapeTransform)) !void {
        const transforms = blockTransforms.items;
        if (self.cubesMap.get(blockId)) |is| {
            var _is = is;
            try cube.Cube.updateInstanced(transforms, &_is);
            try self.cubesMap.put(blockId, _is);
        } else {
            std.debug.print("blockId {d} not found in cubesMap\n", .{blockId});
        }
    }

    fn initChunk(self: *Screen, wpData: position.worldPosition) !void {
        const chunkPosition = wpData.positionFromWorldPosition();
        std.debug.print("initChunk: {d}, {d}, {d}\n", .{ chunkPosition.x, chunkPosition.y, chunkPosition.z });
        var chu = try chunk.Chunk.init(self.alloc);
        var c = &chu;
        defer c.deinit();
        chu.data = self.chunks.get(wpData).?;
        self.shapeview.bind();
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
                        try self.voxelMeshes.put(blockId, _vm);
                    } else {
                        std.debug.print("No voxel mesh for block id: {d}\n", .{blockId});
                    }
                }
            } else {
                @panic("Invalid key type");
            }
        }

        var instancedKeys = c.instanced.keyIterator();
        while (instancedKeys.next()) |_k| {
            if (@TypeOf(_k) == *usize) {
                const i = _k.*;
                const blockId = c.data[i];
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
            } else {
                @panic("Invalid instanced key type");
            }
        }
        self.shapeview.unbind();
    }

    pub fn writeChunks(self: *Screen) !void {
        self.shapeview.bind();

        var chunkKeys = self.chunks.keyIterator();
        while (chunkKeys.next()) |k| {
            if (@TypeOf(k) == *position.worldPosition) {
                try self.initChunk(k.*);
            } else {
                @panic("Invalid key type");
            }
        }
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
        self.shapeview.unbind();
    }

    pub fn toggleWireframe(self: *Screen) void {
        self.wireframe = !self.wireframe;
    }

    pub fn toggleUIMetrics(self: *Screen) void {
        self.showUIMetrics = !self.showUIMetrics;
    }

    pub fn toggleUILog(self: *Screen) void {
        self.showUILog = !self.showUILog;
    }

    pub fn addChunk(self: *Screen, cData: [chunk.chunkSize]i32, p: position.Position) !void {
        const wp = position.worldPosition.initFromPosition(p);
        try self.chunks.put(wp, cData);
    }

    pub fn initChunks(self: *Screen, appState: *state.State) !void {
        self.shapeview.bind();
        try self.addBlocks(appState);
        self.shapeview.unbind();
    }

    pub fn clearChunks(self: *Screen) !void {
        self.shapeview.bind();
        var values = self.voxelMeshes.valueIterator();
        while (values.next()) |v| {
            v.clear();
        }
        var cuv = self.cubesMap.valueIterator();
        const t = [0]instancedShape.InstancedShapeTransform{};
        while (cuv.next()) |v| {
            try v.updateInstanceData(&t);
        }
        var pbtv = self.perBlockTransforms.valueIterator();
        while (pbtv.next()) |v| {
            v.deinit();
        }
        self.perBlockTransforms.clearAndFree();
        self.shapeview.unbind();
    }

    fn pickObject(self: *Screen) !void {
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
