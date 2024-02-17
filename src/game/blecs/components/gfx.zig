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
    vertexShader: [:0]const u8 = undefined,
    fragmentShader: [:0]const u8 = undefined,
    positions: [][3]gl.Float = undefined,
    indices: []u32 = undefined,
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

pub fn init() void {
    ecs.TAG(game.state.world, CanDraw);
    ecs.COMPONENT(game.state.world, BaseRenderer);
    ecs.COMPONENT(game.state.world, ElementsRendererConfig);
    ecs.COMPONENT(game.state.world, ElementsRenderer);
}
