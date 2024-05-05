const game = @import("game/screen_game.zig");
const settings = @import("settings/screen_settings.zig");
const hotkeys = @import("screen_hotkeys.zig");
const camera = @import("screen_camera.zig");
const rotating = @import("screen_rotating.zig");

pub fn init() void {
    hotkeys.init();
    camera.init();
    game.init();
    settings.init();
    rotating.init();
}
