const setup = @import("gfx_setup.zig");
const mesh = @import("gfx_mesh.zig");
const draw = @import("gfx_draw.zig");
const delete = @import("gfx_delete.zig");
const instance_update = @import("gfx_instance_update.zig");

pub fn init() void {
    setup.init();
    mesh.init();
    draw.init();
    delete.init();
    instance_update.init();
}
