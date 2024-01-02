const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state.zig");
const plane = @import("../shape/plane.zig");
const cursor = @import("../shape/cursor.zig");
const cube = @import("../shape/cube.zig");
const shape = @import("../shape/shape.zig");

const chunkSize: comptime_int = 64 * 64 * 64;

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
        // const chunk: [chunkSize]u32 = [_]u32{1} ** chunkSize;
        const chunk: [1]u32 = [_]u32{1};
        try self.worldPlane.draw(self.appState.game.lookAt);
        for (chunk, 0..) |blockId, i| {
            const x = @as(gl.Float, @floatFromInt(@mod(i, 64)));
            const y = @as(gl.Float, @floatFromInt(@mod(i / 64, 64)));
            const z = @as(gl.Float, @floatFromInt(i / (64 * 64)));
            if (self.appState.game.cubesMap.get(blockId)) |is| {
                var m = zm.translation(x, y, z);
                m = zm.mul(m, self.appState.game.lookAt);
                var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
                zm.storeMat(&transform, m);
                try cube.Cube.drawInstanced(transform, is);
            } else {
                std.debug.print("blockId {d} not found in cubesMap\n", .{blockId});
            }
        }
        try self.cursor.draw(self.appState.game.lookAt);
    }
};
