const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const Screen = struct {
    current: u64 = 0,
    gameDataEntity: u64 = 0,
    settingDataEntity: u64 = 0,
};

pub const Data = struct {};
pub const Game = struct {};
pub const Settings = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Screen);
    ecs.TAG(game.state.world, Data);
    ecs.TAG(game.state.world, Game);
    ecs.TAG(game.state.world, Settings);
}
