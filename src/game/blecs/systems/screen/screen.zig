const game = @import("game/screen_game.zig");
const texture_gen = @import("texture_gen/screen_texture_gen.zig");

pub fn init() void {
    game.init();
    texture_gen.init();
}
