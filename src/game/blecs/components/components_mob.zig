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
pub const NeedsSetup = struct {};
pub const NeedsUpdate = struct {};
pub const DidUpdate = struct {};
pub const Texture = struct {};
pub const Walking = struct {};
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
    ecs.TAG(game.state.world, NeedsSetup);
    ecs.TAG(game.state.world, NeedsUpdate);
    ecs.TAG(game.state.world, DidUpdate);
    ecs.TAG(game.state.world, Texture);
    ecs.TAG(game.state.world, Walking);
}
