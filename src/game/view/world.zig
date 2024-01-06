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

    pub fn initChunk(self: *World) !void {
        const initialT: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        var transforms: [drawSize]instancedShape.InstancedShapeTransform = [_]instancedShape.InstancedShapeTransform{
            instancedShape.InstancedShapeTransform{ .transform = initialT },
        } ** drawSize;
        const ds: usize = drawSize;
        var lastIndexDrawn: usize = 0;
        for (self.chunk, 0..) |blockId, i| {
            _ = blockId;
            const x = @as(gl.Float, @floatFromInt(@mod(i, chunkDim)));
            const y = @as(gl.Float, @floatFromInt(@mod(i / chunkDim, chunkDim)));
            const z = @as(gl.Float, @floatFromInt(i / (chunkDim * chunkDim)));
            const m = zm.translation(x, y, z);
            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&transform, m);
            const index = @as(usize, @mod(i, ds));
            const shapesIndex = (i / ds);
            transforms[index] = instancedShape.InstancedShapeTransform{ .transform = transform };
            const _blockId = 1;
            if (index == ds - 1) {
                try self.appState.game.addBlocks(self.appState, _blockId); // increments arraylist for shapes to shapesIndex size
                if (self.appState.game.cubesMap.get(_blockId)) |shapes| {
                    std.debug.print("attempting to update thing items.length {d} at shapesIndex {d}\n", .{ shapes.items.len, shapesIndex });
                    var _is = shapes.items[shapesIndex];
                    std.debug.print("updating thing\n", .{});
                    try cube.Cube.updateInstanced(&transforms, &_is);
                    shapes.items[shapesIndex] = _is;
                } else {
                    std.debug.print("blockId {d} not found in cubesMap\n", .{_blockId});
                }
                // reset transforms
                transforms = [_]instancedShape.InstancedShapeTransform{
                    instancedShape.InstancedShapeTransform{ .transform = initialT },
                } ** ds;
                lastIndexDrawn = shapesIndex;
            }
        }
        std.debug.print("all done, drew {d} \n", .{lastIndexDrawn + 1});
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
            std.debug.print("blockId {d} not found in cubesMap\n", .{1});
        }
        try self.cursor.draw(self.appState.game.lookAt);
    }
};
