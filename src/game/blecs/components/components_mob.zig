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
pub const Texture = struct {};
pub const Walking = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Mob);
    ecs.COMPONENT(game.state.world, Mesh);
    ecs.COMPONENT(game.state.world, Health);
    ecs.TAG(game.state.world, NeedsSetup);
    ecs.TAG(game.state.world, Texture);
    ecs.TAG(game.state.world, Walking);
}
