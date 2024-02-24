const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const Menu = struct {};
pub const GameInfo = struct {};
pub const SettingsCameraOptions = struct {};
pub const DemoCubeOptions = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, Menu);
    ecs.TAG(game.state.world, GameInfo);
    ecs.TAG(game.state.world, SettingsCameraOptions);
    ecs.TAG(game.state.world, DemoCubeOptions);
}
