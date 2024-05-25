pub fn init() void {
    setup.init();
    update.init();
    mesh.init();
    draw.init();
    sorted_multi_draw.init();
    delete.init();
}

const setup = @import("gfx_setup.zig");
const update = @import("gfx_update.zig");
const mesh = @import("gfx_mesh.zig");
const draw = @import("gfx_draw.zig");
const sorted_multi_draw = @import("gfx_sorted_multi_draw.zig");
const delete = @import("gfx_delete.zig");
