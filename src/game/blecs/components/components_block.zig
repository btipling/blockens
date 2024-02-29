const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const game = @import("../../game.zig");

pub const Block = struct {
    block_id: u8 = 0,
};

// Blocks instances are attached to a shape and are instance draws, it does not get a position
// each instance does
pub const BlockInstances = struct {};
// An instance of a block instances adds to the draw count of block instances and gets a position
pub const BlockInstance = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Block);
    ecs.TAG(world, BlockInstances);
    ecs.TAG(world, BlockInstance);
}
