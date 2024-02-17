const gfx = @import("gfx/gfx.zig");
const sky = @import("sky.zig");
const tick = @import("tick.zig");
const hud = @import("hud/hud.zig");
const ui = @import("ui/ui.zig");
const screen = @import("screen/screen.zig");

pub fn init() void {
    gfx.init();
    sky.init();
    tick.init();
    hud.init();
    ui.init();
    screen.init();
}
