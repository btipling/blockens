const gfx = @import("gfx/gfx.zig");
const sky = @import("sky.zig");
const tick = @import("tick.zig");
const hud = @import("hud/hud.zig");

pub fn init() void {
    gfx.init();
    sky.init();
    tick.init();
    hud.init();
}
