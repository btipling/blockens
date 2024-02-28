const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const game = @import("../../game.zig");

pub const Block = struct {
    block_id: u8 = 0,
    instances_id: ecs.entity_t = 0,
};

pub const BlockInstances = struct {
    block_id: u8 = 0,
};
pub const BlockInstance = struct {
    block_id: u8 = 0,
};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Block);
    ecs.COMPONENT(world, BlockInstances);
    ecs.COMPONENT(world, BlockInstance);
}
