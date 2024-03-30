const meshing = @import("block_meshing.zig");
const mesh_rendering = @import("block_mesh_rendering.zig");
const picking = @import("block_picking.zig");

pub fn init() void {
    meshing.init();
    mesh_rendering.init();
    picking.init();
}
