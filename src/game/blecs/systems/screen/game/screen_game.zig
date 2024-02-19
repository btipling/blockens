const hotkeys = @import("game_hotkeys.zig");
const cursor = @import("game_cursor.zig");

pub fn init() void {
    hotkeys.init();
    cursor.init();
}
