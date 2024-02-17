const ecs = @import("zflecs");
const game = @import("../game.zig");

pub const Hud = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, Hud);
}
