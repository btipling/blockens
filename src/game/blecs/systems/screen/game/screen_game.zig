const ecs = @import("zflecs");
const game = @import("../../../../game.zig");
const hotkeys = @import("game_hotkeys.zig");

pub fn init() void {
    hotkeys.init();
}
