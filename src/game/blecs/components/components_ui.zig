const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const Menu = struct {
    visible: bool = false,
};
pub const GameInfo = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Menu);
    ecs.TAG(game.state.world, GameInfo);
}
