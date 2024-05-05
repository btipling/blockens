pub fn init() void {
    hotkeys.init();
    demo_chunk.init();
}

const ecs = @import("zflecs");
const game = @import("../../../../game.zig");
const hotkeys = @import("settings_hotkeys.zig");
const demo_chunk = @import("settings_demo_chunk.zig");
