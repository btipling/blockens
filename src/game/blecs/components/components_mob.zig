const ecs = @import("zflecs");
const game = @import("../../game.zig");
const math = @import("../../math/math.zig");

pub const Mob = struct {
    mob_id: i32 = 0,
    data_entity: ecs.entity_t,
    last_saved: f32 = 0,
};
pub const Mesh = struct {
    mesh_id: usize = 0,
    mob_entity: ecs.entity_t,
};
pub const Health = struct {
    health: u32 = 0,
};
pub const Falling = struct {
    velocity: f32 = 0,
    started: f32 = 0,
};
pub const NeedsSetup = struct {};
pub const NeedsUpdate = struct {};
pub const DidUpdate = struct {};
pub const Texture = struct {};
pub const Walking = struct {
    direction_vector: @Vector(4, f32) = .{ 0, 0, -1, 0 },
    speed: f32 = 0,
    last_moved: f32 = 0,
};
pub const Jumping = struct {
    starting_position: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    jumped_at: f32 = 0,
};
pub const Turning = struct {
    direction_vector: @Vector(4, f32) = .{ 0, 0, -1, 0 },
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    angle: f32 = 0,
    last_moved: f32 = 0,
};
pub const BoundingBox = struct {
    mob_id: i32 = 0,
    mob_entity: ecs.entity_t = 0,
};
pub const Position = struct {
    position: @Vector(4, f32) = .{ 1, 1, 1, 1 },
};
pub const Rotation = struct {
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 },
    angle: f32 = 0,
};
pub const AddAction = struct {};
pub const RemoveAction = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Mob);
    ecs.COMPONENT(world, Mesh);
    ecs.COMPONENT(world, Health);
    ecs.COMPONENT(world, Position);
    ecs.COMPONENT(world, Rotation);
    ecs.COMPONENT(world, BoundingBox);
    ecs.COMPONENT(world, Falling);
    ecs.COMPONENT(world, Walking);
    ecs.COMPONENT(world, Turning);
    ecs.COMPONENT(world, Jumping);
    ecs.TAG(world, NeedsSetup);
    ecs.TAG(world, NeedsUpdate);
    ecs.TAG(world, DidUpdate);
    ecs.TAG(world, Texture);
    ecs.TAG(world, AddAction);
    ecs.TAG(world, RemoveAction);
}
