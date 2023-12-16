const std = @import("std");
const zm = @import("zmath");
const block = @import("block.zig");
const cube = @import("cube.zig");
const plane = @import("plane.zig");

pub const World = struct {
    worldPlane: plane.Plane,
    cube: cube.Cube,
    blocks: std.ArrayList(*block.Block),

    pub fn init(worldPlane: plane.Plane, testCube: cube.Cube, blocks: std.ArrayList(*block.Block)) !World {
        return World{
            .worldPlane = worldPlane,
            .cube = testCube,
            .blocks = blocks,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World, m: zm.Mat) !void {
        try self.worldPlane.draw(m);
        try self.cube.draw(m);
        for (self.blocks.items) |b| {
            try b.draw();
        }
    }
};
