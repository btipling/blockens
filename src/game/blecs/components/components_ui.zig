const ecs = @import("zflecs");
const game = @import("../../game.zig");

pub const UI = struct {
    dialog_count: usize = 0,
};
pub const Menu = struct {};
pub const GameInfo = struct {};
pub const SettingsCamera = struct {};
pub const DemoCube = struct {};
pub const DemoChunk = struct {};
pub const DemoCharacter = struct {};

pub const GameChunksInfo = struct {};
pub const GameMobInfo = struct {};
pub const LightingControls = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, UI);
    ecs.TAG(world, Menu);
    ecs.TAG(world, GameInfo);
    ecs.TAG(world, SettingsCamera);
    ecs.TAG(world, DemoCube);
    ecs.TAG(world, DemoChunk);
    ecs.TAG(world, DemoCharacter);
    ecs.TAG(world, GameChunksInfo);
    ecs.TAG(world, GameMobInfo);
    ecs.TAG(game.state.world, LightingControls);
}
