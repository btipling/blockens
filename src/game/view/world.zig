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

pub const World = struct {
    worldPlane: ?plane.Plane = null,
    cursor: ?cursor.Cursor = null,
    worldView: *state.ViewState,

    pub fn init(worldView: *state.ViewState) !World {
        return World{
            .worldView = worldView,
        };
    }

    pub fn initWithHUD(worldPlane: plane.Plane, c: cursor.Cursor, worldView: *state.ViewState) !World {
        return World{
            .worldPlane = worldPlane,
            .worldView = worldView,
            .cursor = c,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World) !void {
        if (self.worldPlane) |wp| {
            var _wp = wp;
            try _wp.draw(self.worldView.lookAt);
        }

        var instanceShapes = self.worldView.cubesMap.valueIterator();
        while (instanceShapes.next()) |is| {
            try cube.Cube.drawInstanced(is);
        }

        var values = self.worldView.voxelMeshes.valueIterator();
        while (values.next()) |v| {
            try v.draw();
        }

        if (self.cursor) |c| {
            var _c = c;
            try _c.draw(self.worldView.lookAt);
        }
    }
};
