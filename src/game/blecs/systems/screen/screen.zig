const game = @import("game/screen_game.zig");
const settings = @import("settings/screen_settings.zig");
const hotkeys = @import("screen_hotkeys.zig");
const camera = @import("screen_camera.zig");

pub fn init() void {
    hotkeys.init();
    camera.init();
    game.init();
    settings.init();
}
