const std = @import("std");
const block = @import("block.zig");

pub const World = struct {
    blocks: std.ArrayList(*block.Block),

    pub fn init(blocks: std.ArrayList(*block.Block)) !World {
        return World{
            .blocks = blocks,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World) !void {
        for (self.blocks.items) |b| {
            try b.draw();
        }
    }
};
