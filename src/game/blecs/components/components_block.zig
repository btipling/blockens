const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");

pub const Chunk = struct {
    loc: @Vector(4, f32) = undefined,
    wp: chunk.worldPosition = undefined,
};

pub const Block = struct {
    block_id: u8 = 0,
};
pub const BlockData = struct {
    chunk_world_position: chunk.worldPosition = undefined,
    element_index: usize = 0,
    is_settings: bool = false,
};
pub const Meshscale = struct {
    scale: @Vector(4, f32) = undefined,
};
pub const Instance = struct {};
pub const NeedsMeshing = struct {};
pub const NeedsMeshRendering = struct {};
pub const NeedsInstanceRendering = struct {};
pub const UseMultiDraw = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Chunk);
    ecs.COMPONENT(world, Block);
    ecs.COMPONENT(world, BlockData);
    ecs.COMPONENT(world, Meshscale);
    ecs.TAG(world, Instance);
    ecs.TAG(world, NeedsMeshing);
    ecs.TAG(world, NeedsMeshRendering);
    ecs.TAG(world, NeedsInstanceRendering);
    ecs.TAG(world, UseMultiDraw);
}
