pub fn init() void {
    menu.init();
    game_info.init();
    texture_gen.init();
    block_editor.init();
    chunk_editor.init();
    title_screen.init();
    setting_up_screen.init();
    loading_screen.init();
    display_settings.init();
    character_editor.init();
    world_editor.init();
    demo_cube.init();
    demo_chunk.init();
    demo_character.init();
    settings_camera.init();
    game_chunks_info.init();
    game_mob_info.init();
    lighting_controls.init();
    cursor.init();
}
const menu = @import("ui_menu.zig");
const game_info = @import("ui_game_info.zig");
const texture_gen = @import("ui_texture_gen.zig");
const block_editor = @import("ui_block_editor.zig");
const chunk_editor = @import("ui_chunk_editor.zig");
const title_screen = @import("ui_title_screen.zig");
const setting_up_screen = @import("ui_setting_up_screen.zig");
const loading_screen = @import("ui_loading_screen.zig");
const display_settings = @import("ui_display_settings.zig");
const character_editor = @import("ui_character_editor.zig");
const world_editor = @import("ui_world_editor.zig");
const demo_cube = @import("ui_demo_cube.zig");
const demo_chunk = @import("ui_demo_chunk.zig");
const demo_character = @import("ui_demo_character.zig");
const settings_camera = @import("ui_settings_camera.zig");
const game_chunks_info = @import("ui_game_chunks_info.zig");
const game_mob_info = @import("ui_game_mob_info.zig");
const lighting_controls = @import("ui_game_lighting_controls.zig");
const cursor = @import("ui_cursor.zig");
