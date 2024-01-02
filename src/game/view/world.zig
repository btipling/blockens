const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state.zig");
const plane = @import("../shape/plane.zig");
const cursor = @import("../shape/cursor.zig");
const cube = @import("../shape/cube.zig");
const shape = @import("../shape/shape.zig");

const chunkSize: comptime_int = 64 * 64 * 64;
const transformSize = chunkSize * 16;

pub const World = struct {
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

    pub fn draw(self: *World) !void {
        const chunk: [2]u32 = [_]u32{1} ** 2;
        var transforms: [32]gl.Float = [_]gl.Float{undefined} ** 32;
        try self.worldPlane.draw(self.appState.game.lookAt);
        for (chunk, 0..) |blockId, i| {
            _ = blockId;
            const x = @as(gl.Float, @floatFromInt(@mod(i, 64)));
            const y = @as(gl.Float, @floatFromInt(@mod(i / 64, 64)));
            const z = @as(gl.Float, @floatFromInt(i / (64 * 64)));
            var m = zm.translation(x, y, z);
            m = zm.mul(m, self.appState.game.lookAt);
            var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
            zm.storeMat(&transform, m);
            for (0..16) |j| {
                transforms[i * 16 + j] = transform[j];
            }
        }
        if (self.appState.game.cubesMap.get(1)) |is| {
            var _is = is;
            try cube.Cube.drawInstanced(&transforms, &_is);
        } else {
            std.debug.print("blockId {d} not found in cubesMap\n", .{1});
        }
        try self.cursor.draw(self.appState.game.lookAt);
    }
};
