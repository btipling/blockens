const gfx = @import("gfx/gfx.zig");
const sky = @import("sky.zig");
const tick = @import("tick.zig");
const hud = @import("hud/hud.zig");
const ui = @import("ui/ui.zig");

pub fn init() void {
    gfx.init();
    sky.init();
    tick.init();
    hud.init();
    ui.init();
}
