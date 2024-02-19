const menu = @import("ui_menu.zig");
const game_info = @import("ui_game_info.zig");

pub fn init() void {
    menu.init();
    game_info.init();
}
