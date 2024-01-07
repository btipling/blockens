const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state.zig");
const plane = @import("../shape/plane.zig");
const cursor = @import("../shape/cursor.zig");
const cube = @import("../shape/cube.zig");
const shape = @import("../shape/shape.zig");
const instancedShape = @import("../shape/instanced_shape.zig");

const chunkDim = 64;
const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

pub const World = struct {
    chunk: [chunkSize]u32 = [_]u32{1} ** chunkSize,
    worldPlane: plane.Plane,
    cursor: cursor.Cursor,
    appState: *state.State,

    pub fn init(worldPlane: plane.Plane, c: cursor.Cursor, appState: *state.State) !World {
        return World{
            .worldPlane = worldPlane,
            .appState = appState,
            .cursor = c,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn writeAndClear(self: *World, blockId: u32, blockTransforms: *std.ArrayList(instancedShape.InstancedShapeTransform)) !void {
        const transforms = blockTransforms.items;
        const addedAt = try self.appState.game.addBlocks(self.appState, blockId);
        if (self.appState.game.cubesMap.get(blockId)) |shapes| {
            std.debug.print("attempting to update thing items.length {d} at shapesIndex {d}\n", .{ shapes.items.len, addedAt });
            var _is = shapes.items[addedAt];
            std.debug.print("updating thing\n", .{});
            try cube.Cube.updateInstanced(transforms, &_is);
            shapes.items[addedAt] = _is;
        } else {
            std.debug.print("blockId {d} not found in cubesMap\n", .{blockId});
        }
        // reset transforms
        var _b = blockTransforms;
        _b.clearRetainingCapacity();
        std.debug.print("len of blockTransforms after clear {d}\n", .{_b.items.len});
    }

    pub fn initChunk(self: *World, alloc: std.mem.Allocator) !void {
        var perBlockTransforms = std.AutoHashMap(u32, std.ArrayList(instancedShape.InstancedShapeTransform)).init(alloc);
        defer perBlockTransforms.deinit();
        const ds: usize = drawSize;
        _ = ds;
        for (self.chunk, 0..) |blockId, i| {
            const x = @as(gl.Float, @floatFromInt(@mod(i, chunkDim)));
            const y = @as(gl.Float, @floatFromInt(@mod(i / chunkDim, chunkDim)));
            const z = @as(gl.Float, @floatFromInt(i / (chunkDim * chunkDim)));
            const m = zm.translation(x, y, z);
            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&transform, m);
            const t = instancedShape.InstancedShapeTransform{ .transform = transform };

            if (perBlockTransforms.get(blockId)) |blockTransforms| {
                var _blockTransforms = blockTransforms;
                try _blockTransforms.append(t);
                if (_blockTransforms.items.len == drawSize) {
                    std.debug.print("drawing? {d} \n", .{_blockTransforms.items.len});
                    try self.writeAndClear(blockId, &_blockTransforms);
                    std.debug.print("len of blockTransforms after clear {d}\n", .{_blockTransforms.items.len});
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
            std.debug.print("deiniting with values {d}\n", .{v.items.len});
            v.deinit();
        }
    }

    pub fn draw(self: *World) !void {
        const _blockId = 1;
        try self.worldPlane.draw(self.appState.game.lookAt);
        if (self.appState.game.cubesMap.get(_blockId)) |shapes| {
            for (shapes.items) |is| {
                var _is = is;
                try cube.Cube.drawInstanced(&_is);
            }
        } else {
            std.debug.print("blockId {d} not found in cubesMap\n", .{_blockId});
        }
        try self.cursor.draw(self.appState.game.lookAt);
    }
};
