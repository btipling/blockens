const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const Chunk = struct {
    loc: @Vector(4, f32) = undefined,
};

pub const Block = struct {
    block_id: u8 = 0,
};
pub const Meshscale = struct {
    scale: @Vector(4, f32) = undefined,
};
pub const Instance = struct {};
pub const NeedsMeshing = struct {};
pub const NeedsMeshRendering = struct {};
pub const NeedsInstanceRendering = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Chunk);
    ecs.COMPONENT(world, Block);
    ecs.COMPONENT(world, Meshscale);
    ecs.TAG(world, Instance);
    ecs.TAG(world, NeedsMeshing);
    ecs.TAG(world, NeedsMeshRendering);
    ecs.TAG(world, NeedsInstanceRendering);
}
