const gfx = @import("entities_gfx.zig");
const screen = @import("entities_screen.zig");

pub fn init() void {
    gfx.init();
    screen.init();
}
