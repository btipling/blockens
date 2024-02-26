const menu = @import("ui_menu.zig");
const game_info = @import("ui_game_info.zig");
const texture_gen = @import("ui_texture_gen.zig");
const block_config = @import("ui_block_config.zig");
const demo_cube = @import("ui_demo_cube.zig");
const settings_camera = @import("ui_settings_camera.zig");
const cursor = @import("ui_cursor.zig");

pub fn init() void {
    menu.init();
    game_info.init();
    texture_gen.init();
    block_config.init();
    demo_cube.init();
    settings_camera.init();
    cursor.init();
}
