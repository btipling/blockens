const std = @import("std");
const zm = @import("zmath");
const block = @import("block.zig");
const cube = @import("cube.zig");

pub const World = struct {
    cube: cube.Cube,
    blocks: std.ArrayList(*block.Block),

    pub fn init(testCube: cube.Cube, blocks: std.ArrayList(*block.Block)) !World {
        return World{
            .cube = testCube,
            .blocks = blocks,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World, m: zm.Mat) !void {
        try self.cube.draw(m);
        for (self.blocks.items) |b| {
            try b.draw();
        }
    }
};
