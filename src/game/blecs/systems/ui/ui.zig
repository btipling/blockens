const menu = @import("ui_menu.zig");
const game_info = @import("ui_game_info.zig");
const texture_gen = @import("ui_texture_gen.zig");

pub fn init() void {
    menu.init();
    game_info.init();
    texture_gen.init();
}
