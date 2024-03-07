const menu = @import("ui_menu.zig");
const game_info = @import("ui_game_info.zig");
const texture_gen = @import("ui_texture_gen.zig");
const block_editor = @import("ui_block_editor.zig");
const chunk_editor = @import("ui_chunk_editor.zig");
const character_editor = @import("ui_character_editor.zig");
const world_editor = @import("ui_world_editor.zig");
const demo_cube = @import("ui_demo_cube.zig");
const demo_chunk = @import("ui_demo_chunk.zig");
const demo_character = @import("ui_demo_character.zig");
const settings_camera = @import("ui_settings_camera.zig");
const cursor = @import("ui_cursor.zig");

pub fn init() void {
    menu.init();
    game_info.init();
    texture_gen.init();
    block_editor.init();
    chunk_editor.init();
    character_editor.init();
    world_editor.init();
    demo_cube.init();
    demo_chunk.init();
    demo_character.init();
    settings_camera.init();
    cursor.init();
}
