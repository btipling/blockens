const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state.zig");
const plane = @import("../shape/plane.zig");
const cursor = @import("../shape/cursor.zig");
const cube = @import("../shape/cube.zig");
const position = @import("../position.zig");
const shape = @import("../shape/shape.zig");
const instancedShape = @import("../shape/instanced_shape.zig");

const chunkDim = 64;
const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

pub const World = struct {
    chunk: [chunkSize]u32 = [_]u32{1} ** chunkSize,
    worldPlane: ?plane.Plane = null,
    cursor: ?cursor.Cursor = null,
    appState: *state.State,
    worldView: *state.ViewState,

    pub fn init(appState: *state.State, worldView: *state.ViewState) !World {
        return World{
            .appState = appState,
            .worldView = worldView,
        };
    }

    pub fn initWithHUD(worldPlane: plane.Plane, c: cursor.Cursor, appState: *state.State, worldView: *state.ViewState) !World {
        return World{
            .worldPlane = worldPlane,
            .appState = appState,
            .worldView = worldView,
            .cursor = c,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn writeAndClear(self: *World, blockId: u32, blockTransforms: *std.ArrayList(instancedShape.InstancedShapeTransform)) !void {
        const transforms = blockTransforms.items;
        const addedAt = try self.worldView.addBlocks(self.appState, blockId);
        if (self.worldView.cubesMap.get(blockId)) |shapes| {
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

    pub fn randomChunk(self: *World) [chunkSize]u32 {
        var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();
        const maxOptions = self.worldView.blockOptions.items.len - 1;
        var chunk: [chunkSize]u32 = [_]u32{undefined} ** chunkSize;
        for (chunk, 0..) |_, i| {
            const randomInt = random.uintAtMost(usize, maxOptions);
            const blockId = @as(u32, @intCast(randomInt + 1));
            chunk[i] = blockId;
        }
        return chunk;
    }

    pub fn initChunk(self: *World, chunk: [chunkSize]u32, alloc: std.mem.Allocator, chunkPosition: position.Position) !void {
        var perBlockTransforms = std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShapeTransform)).init(alloc);
        defer perBlockTransforms.deinit();
        for (chunk, 0..) |blockId, i| {
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
                    try self.writeAndClear(blockId, &_blockTransforms);
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
            if (@TypeOf(_k) == u32) {
                const k = _k.*;
                if (perBlockTransforms.get(k)) |blockTransforms| {
                    try self.writeAndClear(k, blockTransforms);
                }
            }
        }
        var values = perBlockTransforms.valueIterator();
        while (values.next()) |v| {
            v.deinit();
        }
    }

    pub fn draw(self: *World) !void {
        if (self.worldPlane) |wp| {
            var _wp = wp;
            try _wp.draw(self.worldView.lookAt);
        }

        var keys = self.worldView.cubesMap.keyIterator();
        while (keys.next()) |_k| {
            const _blockId = _k.*;
            if (self.worldView.cubesMap.get(_blockId)) |shapes| {
                for (shapes.items) |is| {
                    var _is = is;
                    try cube.Cube.drawInstanced(&_is);
                }
            } else {
                std.debug.print("blockId {d} not found in cubesMap\n", .{_blockId});
            }
        }

        if (self.cursor) |c| {
            var _c = c;
            try _c.draw(self.worldView.lookAt);
        }
    }
};
