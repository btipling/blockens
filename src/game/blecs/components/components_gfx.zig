const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
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
    texture: gl.Uint = 0,
    numIndices: gl.Int = 0,
    enableDepthTest: bool = true,
};

pub const AnimationSSBO = struct {
    ssbo: gl.Uint = 0,
    animation_id: gl.Float = 0,
};

pub const AnimationKeyFrame = struct {
    frame: gl.Float = 0,
    scale: @Vector(4, gl.Float) = @Vector(4, gl.Float){ 1, 1, 1, 1 },
    rotation: @Vector(4, gl.Float) = @Vector(4, gl.Float){ 1, 0, 0, 0 },
    translation: @Vector(4, gl.Float) = @Vector(4, gl.Float){ 0, 0, 0, 0 },
};

pub const CanDraw = struct {};
pub const NeedsInstanceDataUpdate = struct {};
pub const NeedsDeletion = struct {};

pub const Wireframe = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, BaseRenderer);
    ecs.COMPONENT(world, ElementsRendererConfig);
    ecs.COMPONENT(world, ElementsRenderer);
    ecs.COMPONENT(world, AnimationSSBO);
    ecs.COMPONENT(world, AnimationKeyFrame);
    ecs.TAG(world, CanDraw);
    ecs.TAG(world, NeedsInstanceDataUpdate);
    ecs.TAG(world, NeedsDeletion);
    ecs.TAG(world, Wireframe);
}
