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
    num_indices: gl.Int = 0,
    enable_depth_test: bool = true,
};

pub const AnimationMesh = struct {
    animation_id: u32 = 0,
    mesh_id: u8 = 0,
};

pub const AnimationKeyFrame = struct {
    frame: f32 = 0,
    scale: @Vector(4, f32) = @Vector(4, f32){ 1, 1, 1, 1 },
    rotation: @Vector(4, f32) = @Vector(4, f32){ 1, 0, 0, 0 },
    translation: @Vector(4, f32) = @Vector(4, f32){ 0, 0, 0, 0 },
};
pub const HasPreviousRenderer = struct {
    entity: ecs.entity_t,
};

pub const CanDraw = struct {};
pub const SortedMultiDraw = struct {};
pub const ManuallyHidden = struct {};
pub const NeedsUniformUpdate = struct {};
pub const NeedsDeletion = struct {};
pub const IsPreviousRenderer = struct {};

pub const Wireframe = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, BaseRenderer);
    ecs.COMPONENT(world, ElementsRendererConfig);
    ecs.COMPONENT(world, ElementsRenderer);
    ecs.COMPONENT(world, AnimationMesh);
    ecs.COMPONENT(world, AnimationKeyFrame);
    ecs.COMPONENT(world, HasPreviousRenderer);
    ecs.TAG(world, CanDraw);
    ecs.TAG(world, SortedMultiDraw);
    ecs.TAG(world, ManuallyHidden);
    ecs.TAG(world, NeedsUniformUpdate);
    ecs.TAG(world, NeedsDeletion);
    ecs.TAG(world, Wireframe);
    ecs.TAG(world, IsPreviousRenderer);
}

const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
