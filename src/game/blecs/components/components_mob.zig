const gl = @import("zopengl").bindings;
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const math = @import("../../math/math.zig");

pub const Mob = struct {
    mob_id: i32 = 0,
};
pub const Health = struct {
    health: u32 = 0,
};
pub const NeedsSetup = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Mob);
    ecs.COMPONENT(game.state.world, Health);
    ecs.TAG(game.state.world, NeedsSetup);
}
