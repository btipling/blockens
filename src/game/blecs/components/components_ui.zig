const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const UI = struct {};
pub const Menu = struct {};
pub const GameInfo = struct {};
pub const SettingsCamera = struct {};
pub const DemoCube = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, UI);
    ecs.TAG(game.state.world, Menu);
    ecs.TAG(game.state.world, GameInfo);
    ecs.TAG(game.state.world, SettingsCamera);
    ecs.TAG(game.state.world, DemoCube);
}
