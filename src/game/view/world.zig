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
        for (self.chunk, 0..) |blockId, i| {
            _ = blockId;
            const x = @as(gl.Float, @floatFromInt(@mod(i, chunkDim)));
            const y = @as(gl.Float, @floatFromInt(@mod(i / chunkDim, chunkDim)));
            const z = @as(gl.Float, @floatFromInt(i / (chunkDim * chunkDim)));
            const m = zm.translation(x, y, z);
            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&transform, m);
            const index = @as(usize, @mod(i, drawSize));
            transforms[index] = instancedShape.InstancedShapeTransform{ .transform = transform };
            if (index == drawSize - 1) {
                if (self.appState.game.cubesMap.get(1)) |is| {
                    var _is = is;
                    try cube.Cube.updateInstanced(&transforms, &_is);
                    try self.appState.game.cubesMap.put(1, _is);
                } else {
                    std.debug.print("blockId {d} not found in cubesMap\n", .{1});
                }
                // reset transforms
                transforms = [_]instancedShape.InstancedShapeTransform{
                    instancedShape.InstancedShapeTransform{ .transform = initialT },
                } ** drawSize;
            }
        }

        try self.cursor.draw(self.appState.game.lookAt);
    }

    pub fn draw(self: *World) !void {
        try self.worldPlane.draw(self.appState.game.lookAt);
        for (self.chunk, 0..) |blockId, i| {
            _ = blockId;
            const index = @as(usize, @mod(i, drawSize));
            if (index == drawSize - 1) {
                if (self.appState.game.cubesMap.get(1)) |is| {
                    var _is = is;
                    try cube.Cube.drawInstanced(&_is);
                } else {
                    std.debug.print("blockId {d} not found in cubesMap\n", .{1});
                }
            }
        }

        try self.cursor.draw(self.appState.game.lookAt);
    }
};
