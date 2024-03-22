const ecs = @import("zflecs");
const game = @import("../../game.zig");
const math = @import("../../math/math.zig");

pub const Mob = struct {
    mob_id: i32 = 0,
    data_entity: ecs.entity_t,
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
pub const Texture = struct {};
pub const Walking = struct {};
pub const Position = struct {
    position: @Vector(4, f32) = .{ 1, 1, 1, 1 },
};
pub const Rotation = struct {
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 },
    angle: f32 = 0,
    mouse_moved: bool = false,
};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Mob);
    ecs.COMPONENT(game.state.world, Mesh);
    ecs.COMPONENT(game.state.world, Health);
    ecs.COMPONENT(game.state.world, Position);
    ecs.COMPONENT(game.state.world, Rotation);
    ecs.TAG(game.state.world, NeedsSetup);
    ecs.TAG(game.state.world, NeedsUpdate);
    ecs.TAG(game.state.world, Texture);
    ecs.TAG(game.state.world, Walking);
}
