const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");

pub const BaseRenderer = struct {
    clear: gl.Bitfield = 0,
    bgColor: math.vecs.Vflx4 = undefined,
};

pub const ElementsRendererConfig = struct {
    id: ecs.entity_t,
};

pub const ElementsRenderer = struct {
    program: gl.Uint = 0,
    vao: gl.Uint = 0,
    vbo: gl.Uint = 0,
    ebo: gl.Uint = 0,
    numIndices: gl.Int = 0,
    enableDepthTest: bool = true,
};

// Tags
pub const CanDraw = struct {};
pub const NeedsDeletion = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, BaseRenderer);
    ecs.COMPONENT(game.state.world, ElementsRendererConfig);
    ecs.COMPONENT(game.state.world, ElementsRenderer);
    ecs.TAG(game.state.world, CanDraw);
    ecs.TAG(game.state.world, NeedsDeletion);
}
