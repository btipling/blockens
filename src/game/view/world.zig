const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state/state.zig");
const plane = @import("../shape/plane.zig");
const cursor = @import("../shape/cursor.zig");
const cube = @import("../shape/cube.zig");
const shape = @import("../shape/shape.zig");
const instancedShape = @import("../shape/instanced_shape.zig");

pub const World = struct {
    worldPlane: ?plane.Plane = null,
    cursor: ?cursor.Cursor = null,
    worldScreen: *state.screen.Screen,
    numVoxelMeshesDrawn: usize = 0,

    pub fn init(worldScreen: *state.screen.Screen) !World {
        return World{
            .worldScreen = worldScreen,
        };
    }

    pub fn initWithHUD(worldPlane: plane.Plane, c: cursor.Cursor, worldScreen: *state.screen.Screen) !World {
        return World{
            .worldPlane = worldPlane,
            .worldScreen = worldScreen,
            .cursor = c,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World) !void {
        if (self.worldScreen.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
        }

        if (self.worldPlane) |wp| {
            var _wp = wp;
            try _wp.draw(self.worldScreen.lookAt);
        }

        var instanceShapes = self.worldScreen.cubesMap.valueIterator();
        while (instanceShapes.next()) |is| {
            try cube.Cube.drawInstanced(is);
        }

        var totalItemsDrawn: usize = 0;
        var keys = self.worldScreen.voxelMeshes.keyIterator();
        while (keys.next()) |_k| {
            if (@TypeOf(_k) == *i32) {
                const blockId = _k.*;
                if (self.worldScreen.voxelMeshes.get(blockId)) |vm| {
                    if (vm.voxelShape.voxelData.items.len == 0) {
                        continue;
                    }
                    var _vm = vm;
                    var v = &_vm;
                    try v.draw();
                    totalItemsDrawn += v.voxelShape.voxelData.items.len;
                }
            }
        }
        if (totalItemsDrawn != self.numVoxelMeshesDrawn) {
            std.debug.print(
                "num voxel meshes drawn changed from {d} to {d}\n",
                .{
                    self.numVoxelMeshesDrawn,
                    totalItemsDrawn,
                },
            );
            self.numVoxelMeshesDrawn = totalItemsDrawn;
        }

        if (self.cursor) |c| {
            var _c = c;
            try _c.draw(self.worldScreen.lookAt);
        }
        if (self.worldScreen.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
        }
    }
};
