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
    program: u32 = 0,
    vao: u32 = 0,
    vbo: u32 = 0,
    ebo: u32 = 0,
    texture: u32 = 0,
    numIndices: gl.Int = 0,
    enableDepthTest: bool = true,
};

pub const AnimationSSBO = struct {
    ssbo: u32 = 0,
    animation_id: u32 = 0,
};

pub const AnimationKeyFrame = struct {
    frame: f32 = 0,
    scale: @Vector(4, f32) = @Vector(4, f32){ 1, 1, 1, 1 },
    rotation: @Vector(4, f32) = @Vector(4, f32){ 1, 0, 0, 0 },
    translation: @Vector(4, f32) = @Vector(4, f32){ 0, 0, 0, 0 },
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
