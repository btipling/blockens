pub const Chunk = struct {
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
pub const ChunkUpdate = struct {
    pos: @Vector(4, f32),
    block_id: u8,
};
pub const SubChunks = struct {
    mesh_binding_point: u32,
    draw_binding_point: u32,
};
pub const HighlightedBlock = struct {};
pub const NeedsMeshing = struct {};
pub const NeedsMeshRendering = struct {};
pub const NeedsInstanceRendering = struct {};
pub const UseMultiDraw = struct {};
pub const UseTextureAtlas = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Chunk);
    ecs.COMPONENT(world, Block);
    ecs.COMPONENT(world, BlockData);
    ecs.COMPONENT(world, Meshscale);
    ecs.COMPONENT(world, ChunkUpdate);
    ecs.COMPONENT(world, SubChunks);
    ecs.TAG(world, HighlightedBlock);
    ecs.TAG(world, NeedsMeshing);
    ecs.TAG(world, NeedsMeshRendering);
    ecs.TAG(world, NeedsInstanceRendering);
    ecs.TAG(world, UseMultiDraw);
    ecs.TAG(world, UseTextureAtlas);
}

const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
