const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const game = @import("../../game.zig");

pub const Block = struct {
    block_id: u8 = 0,
};
pub const BlockInstance = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Block);
    ecs.TAG(world, BlockInstance);
}
