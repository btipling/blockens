const setup = @import("gfx_setup.zig");
const mesh = @import("gfx_mesh.zig");
const draw = @import("gfx_draw.zig");
const delete = @import("gfx_delete.zig");

pub fn init() void {
    setup.init();
    mesh.init();
    draw.init();
    delete.init();
}
