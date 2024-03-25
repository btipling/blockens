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
    started: i64 = 0,
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
pub const Turning = struct {
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

pub fn init() void {
    ecs.COMPONENT(game.state.world, Mob);
    ecs.COMPONENT(game.state.world, Mesh);
    ecs.COMPONENT(game.state.world, Health);
    ecs.COMPONENT(game.state.world, Position);
    ecs.COMPONENT(game.state.world, Rotation);
    ecs.COMPONENT(game.state.world, BoundingBox);
    ecs.COMPONENT(game.state.world, Falling);
    ecs.COMPONENT(game.state.world, Walking);
    ecs.COMPONENT(game.state.world, Turning);
    ecs.TAG(game.state.world, NeedsSetup);
    ecs.TAG(game.state.world, NeedsUpdate);
    ecs.TAG(game.state.world, DidUpdate);
    ecs.TAG(game.state.world, Texture);
}
