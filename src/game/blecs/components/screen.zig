const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const Screen = struct {};
pub const Game = struct {};
pub const Settings = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, Screen);
    ecs.TAG(game.state.world, Game);
    ecs.TAG(game.state.world, Settings);
}

pub fn clearScreens(entity: ecs.entity_t) void {
    ecs.remove(game.state.world, entity, Game);
    ecs.remove(game.state.world, entity, Settings);
}
