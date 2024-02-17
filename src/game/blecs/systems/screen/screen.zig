const game = @import("game/screen_game.zig");
const settings = @import("settings/screen_settings.zig");
const hotkeys = @import("screen_hotkeys.zig");

pub fn init() void {
    hotkeys.init();
    game.init();
    settings.init();
}
