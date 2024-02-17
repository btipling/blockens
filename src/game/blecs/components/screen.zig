const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const Screen = struct {};
pub const Game = struct {};
pub const TextureGen = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, Screen);
    ecs.TAG(game.state.world, Game);
    ecs.TAG(game.state.world, TextureGen);
}
