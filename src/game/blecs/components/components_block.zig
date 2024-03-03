const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const game = @import("../../game.zig");

pub const Chunk = struct {
    loc: @Vector(4, gl.Float) = undefined,
};

pub const Block = struct {
    block_id: u8 = 0,
};
pub const Meshscale = struct {
    scale: @Vector(4, gl.Float) = undefined,
};
pub const Instance = struct {};
pub const NeedsMeshing = struct {};
pub const NeedsRendering = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Chunk);
    ecs.COMPONENT(world, Block);
    ecs.COMPONENT(world, Meshscale);
    ecs.TAG(world, Instance);
    ecs.TAG(world, NeedsMeshing);
    ecs.TAG(world, NeedsRendering);
}
