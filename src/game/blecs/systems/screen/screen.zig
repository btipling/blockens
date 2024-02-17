const game = @import("game/screen_game.zig");
const texture_gen = @import("texture_gen/screen_texture_gen.zig");
const hotkeys = @import("screen_hotkeys.zig");

pub fn init() void {
    hotkeys.init();
    game.init();
    texture_gen.init();
}
