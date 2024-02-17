const ecs = @import("zflecs");
const game = @import("../../../../game.zig");
const hotkeys = @import("settings_hotkeys.zig");

pub fn init() void {
    hotkeys.init();
}
