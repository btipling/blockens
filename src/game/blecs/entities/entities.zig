const gfx = @import("entities_gfx.zig");
const ui = @import("entities_ui.zig");
pub const screen = @import("entities_screen.zig");
pub const block = @import("entities_block.zig");

pub fn init() void {
    // This order matters, screen inits public staticvalues used below.
    screen.init();
    gfx.init();
    ui.init();
    block.init();
}
